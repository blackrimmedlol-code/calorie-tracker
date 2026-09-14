#!/usr/bin/env bash
# push-data.sh — 卡路里看板安全推送（通用版，不依赖任何国内网络加固）
#
# 用法（在仓库根目录）:
#   bash tools/push-data.sh "9-14 晚餐：台式炸鸡+卤肉饭（1180大卡，全天2532）"
#
# 固定顺序（HERMES_DATA_GUIDE.md 硬性约束）:
#   同步远端 → 校验 data.json → 只 add data.json → 有改动才 commit → push → 验证不 ahead
#
# 安全规则内置:
#   - 只提交 data.json（禁止 git add -A）
#   - push 前检查本地领先提交里不含 market/ 文件
#   - JSON 校验不通过直接 ABORT，不带病提交
#   - 错误分类: rejected/non-fast-forward = Git 同步错误 → 只 rebase+重推一次；
#               超时/不可达 = 网络错误 → 重试有上限（默认 3 次），禁止长循环
set -u
cd "$(git rev-parse --show-toplevel)" || exit 1
MSG="${1:-更新数据}"
ATTEMPTS="${ATTEMPTS:-3}"
VALIDATOR="$(dirname "$0")/validate-calorie-data.py"

restore_stash() { [ "${STASHED:-0}" = "1" ] && git stash pop >/dev/null 2>&1; }
STASHED=0
trap restore_stash EXIT

# 0. 前置处理工作区脏（"先写后推"最常见）
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  if git status --porcelain | grep -vq '^ M data.json$'; then
    git stash push -m "push-data auto-stash $(date +%Y%m%d%H%M%S)" >/dev/null 2>&1 && STASHED=1
    echo "工作区含 data.json 以外改动，已自动 stash（pull 后恢复）"
  elif [ "$(git rev-list --count origin/main..HEAD 2>/dev/null)" = "0" ]; then
    python3 "$VALIDATOR" data.json || { echo "ABORT: 提交前校验未通过"; exit 1; }
    git add -- data.json
    git commit -m "$MSG" -q
    echo "pre-committed: $MSG"
  else
    git stash push -m "push-data auto-stash $(date +%Y%m%d%H%M%S)" >/dev/null 2>&1 && STASHED=1
    echo "本地有领先提交且 data.json 已改动，已自动 stash"
  fi
fi

# 1. pull --rebase（网络类重试上限 2 次）
for i in 1 2; do
  out=$(timeout 90 git pull --rebase origin main 2>&1); rc=$?
  echo "$out" | tail -1
  [ $rc -eq 0 ] && break
  if git rev-parse -q --verify REBASE_HEAD >/dev/null 2>&1; then
    git rebase --abort >/dev/null 2>&1
    echo "REBASE_CONFLICT: 合并冲突，已中止并保留本地数据，需人工处理"; exit 1
  fi
  echo "pull 失败(exit $rc，网络类)，5s 后重试 ($i/2)"; sleep 5
done
[ $rc -eq 0 ] || { echo "PULL_FAILED: 网络类失败 2 次，稍后重跑"; exit 1; }

if [ "$STASHED" = "1" ]; then
  popout=$(git stash pop 2>&1); prc=$?
  echo "$popout" | tail -1
  [ $prc -eq 0 ] || { echo "STASH_POP_CONFLICT: 改动仍在 git stash list，需人工处理"; exit 1; }
  STASHED=0; echo "已恢复暂存的本地改动"
fi

# 2. market/ 安全检查
if git diff --name-only origin/main...HEAD 2>/dev/null | grep -q '^market/'; then
  echo "ABORT: 本地提交包含 market/ 文件，禁止推送"; git diff --name-only origin/main...HEAD; exit 1
fi

# 3. 校验 + 提交（有改动才做）
if ! git diff --quiet -- data.json 2>/dev/null; then
  python3 "$VALIDATOR" data.json || { echo "ABORT: data.json 校验未通过，禁止提交"; exit 1; }
  git add -- data.json
  git commit -m "$MSG" -q
  echo "committed: $MSG"
else
  echo "data.json 无改动，跳过 commit"
fi

# 4. push
PUSHED=0; REBASED=0
if [ "$(git rev-list --count origin/main..HEAD 2>/dev/null)" = "0" ] && git diff --quiet -- data.json 2>/dev/null; then
  echo "无待推送内容，跳过 push"; PUSHED=1
else
  for i in $(seq 1 "$ATTEMPTS"); do
    out=$(timeout 90 git push origin main 2>&1); rc=$?
    echo "$out" | tail -1
    if [ $rc -eq 0 ]; then echo "PUSH_OK attempt=$i"; PUSHED=1; break; fi
    if echo "$out" | grep -qiE 'rejected|non-fast-forward|Updates were rejected'; then
      [ "$REBASED" = "1" ] && { echo "GIT_DESYNC: rebase 后重推仍被拒，立即停止，需人工排查"; exit 1; }
      echo "远端有新提交（Git 同步错误），fetch+rebase 一次"
      pullout=$(timeout 90 git pull --rebase origin main 2>&1); prc=$?
      echo "$pullout" | tail -2
      if [ $prc -ne 0 ]; then
        if git rev-parse -q --verify REBASE_HEAD >/dev/null 2>&1; then
          git rebase --abort >/dev/null 2>&1
          echo "REBASE_CONFLICT: rebase 合并冲突，已中止并保留本地数据" 
        else
          echo "GIT_DESYNC: rebase 拉取失败(exit $prc)，立即停止"
        fi
        exit 1
      fi
      REBASED=1
      ! git diff --quiet -- data.json 2>/dev/null && { python3 "$VALIDATOR" data.json || { echo "ABORT: rebase 后校验未通过"; exit 1; }; }
      if git diff --name-only origin/main...HEAD 2>/dev/null | grep -q '^market/'; then
        echo "ABORT: rebase 后本地领先提交包含 market/ 文件"; exit 1
      fi
      out2=$(timeout 90 git push origin main 2>&1); rc=$?
      echo "$out2" | tail -1
      if [ $rc -eq 0 ]; then echo "PUSH_OK attempt=$i (rebase后)"; PUSHED=1; break; fi
      if echo "$out2" | grep -qiE 'rejected|non-fast-forward|Updates were rejected'; then
        echo "GIT_DESYNC: rebase 后重推仍被拒，立即停止"; exit 1
      fi
    fi
    echo "push 失败(exit $rc，网络类)，重试 ($i/$ATTEMPTS)"; sleep 5
  done
fi
[ $PUSHED -eq 1 ] || { echo "PUSH_FAILED — 网络类失败 $ATTEMPTS 次均未成功（上限已到，禁止继续循环）"; exit 1; }

# 5. 验证远端同步
timeout 90 git fetch origin main --quiet 2>/dev/null
if git status -sb | grep -q 'ahead'; then
  echo "STILL_AHEAD — 推送未成功"; git status -sb; exit 1
else
  echo "SYNCED"; git status -sb
fi

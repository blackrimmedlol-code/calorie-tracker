#!/usr/bin/env bash
# git-push-retry.sh — 卡路里看板推送封装（国内出口限流环境强化版）
# 用法（在仓库根目录）: bash tools/git-push-retry.sh "8-25 晚餐：xxx（510大卡，全天1050）"
#   可选环境变量: ATTEMPTS=3（网络类重试上限） PROBE_TO=12（探测超时秒数）
# 网络正常的环境直接用 tools/push-data.sh 即可，不需要本脚本的 IP 钉逻辑。
# 背景: 腾讯云国际出口对 github.com 链路间歇性 QoS 限流（分钟级波动）。应对: 每次操作前并行
#   探测候选 IP 中完整走通 HTTPS 的置顶重试；低速 30s 快速失败（全局 curloptResolve 配置）。
# 错误分类（HERMES_DATA_GUIDE.md 硬性约束，勿混为一谈）:
#   - rejected / non-fast-forward / SHA 分叉 = Git 同步错误（远端有新提交），
#     只允许 重新 fetch/rebase → 重新校验 JSON → 重试推送一次；再失败立即停止报错，禁止多轮重试。
#   - curl 28 / 连接超时 / 网络不可达 = 网络错误，换 IP 重试，上限 ATTEMPTS 次，禁止长循环。
#   - 工作区脏（Please commit or stash them）= 本地未提交改动（最常见「先写后推」），
#     前置步骤自动处理：仅 data.json 改动 → 校验后直接提交；含其他文件 → stash→pull→pop。
# 流程: pull(--rebase,用探测IP) → 校验 JSON → 只 add data.json → commit(有改动才提)
#      → push(网络类<=ATTEMPTS次; 同步类只 rebase+重推一次) → 验证远端同步
# 安全规则内置: 只动 data.json、禁止 -A、push 前检查无 market/ 文件、验证后不 ahead
set -u
cd "$(git rev-parse --show-toplevel)" || exit 1
MSG="${1:-更新数据}"
ATTEMPTS="${ATTEMPTS:-3}"
PROBE_TO="${PROBE_TO:-12}"

# 异常退出时恢复被暂存的本地改动（正常路径 pop 后 STASHED=0，trap 不再动作）
STASHED=0
restore_stash() { [ "${STASHED:-0}" = "1" ] && git stash pop >/dev/null 2>&1; }
trap restore_stash EXIT

# GitHub IP 候选（2026-08-29 重扫自 api.github.com/meta；HTTPS 实测 200 的置顶）
IP_CANDIDATES=(
  20.27.177.113 20.87.245.0 4.208.26.197
  20.27.177.118 20.200.245.248 20.205.243.166 20.205.243.160 20.207.73.83 20.207.73.82
  4.237.22.38 4.237.22.40 20.29.134.19 185.199.108.1 20.233.83.149 20.233.83.145
  172.182.252.135 4.249.131.163 4.208.26.198 20.87.245.0 48.204.201.5 48.202.248.40
  140.82.113.4 140.82.114.4 140.82.112.6 140.82.114.6 140.82.121.3 140.82.112.3
)

# 并行探测（PROBE_TO 秒上限），返回第一个完整走通 HTTPS 的 IP；全挂返回空
pick_ip() {
  local out; out=$(mktemp -d)
  for ip in "${IP_CANDIDATES[@]}"; do
    ( timeout "$PROBE_TO" curl -sS --resolve "github.com:443:$ip" -o /dev/null \
        -w '%{http_code}' https://github.com/ 2>/dev/null | grep -q '^200$' \
      && echo "$ip" > "$out/$ip" ) &
  done
  wait 2>/dev/null
  local ip
  for ip in "${IP_CANDIDATES[@]}"; do
    [ -f "$out/$ip" ] && { rm -rf "$out"; echo "$ip"; return 0; }
  done
  rm -rf "$out"
  return 1
}

# 生成 curloptResolve 字符串（格式: host:port:ip1,ip2,ip3 — 前缀只出现一次！best 置顶）
resolve_for() {
  local best="$1" r="github.com:443:$best" ip
  for ip in "${IP_CANDIDATES[@]}"; do
    [ "$ip" != "$best" ] && r="$r,$ip"
  done
  echo "$r"
}

# 校验 data.json（指南硬性约束）；致命错误则中止，禁止带病提交
validate_json() {
  python3 "$(dirname "$0")/validate-calorie-data.py" >/tmp/push-validate.log 2>&1
}

# 0. 前置处理工作区脏（根治: 先写后推时 pull 报 Please commit or stash them 被误判为网络错误）
#    仅 data.json 改动 + 本地无领先提交 → 校验后直接提交（最常见）；含其他文件改动 → stash 暂存，pull 后 pop
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  if git status --porcelain | grep -vq '^ M data.json$'; then
    git stash push -m "git-push-retry auto-stash $(date +%Y%m%d%H%M%S)" >/dev/null 2>&1 && STASHED=1
    echo "工作区含 data.json 以外改动，已自动 stash（pull 后恢复，其他文件保持未提交）"
  elif [ "$(git rev-list --count origin/main..HEAD 2>/dev/null)" = "0" ]; then
    validate_json || { echo "ABORT: 前置提交前 data.json 校验未通过"; tail -5 /tmp/push-validate.log; exit 1; }
    git add -- data.json
    git -c user.name="blackrimdol-code" -c user.email="blackrimdol@gmail.com" commit -m "$MSG" -q
    echo "pre-committed: $MSG"
  else
    git stash push -m "git-push-retry auto-stash $(date +%Y%m%d%H%M%S)" >/dev/null 2>&1 && STASHED=1
    echo "本地有领先提交且 data.json 已改动，自动 stash（rebase 后恢复）"
  fi
fi

# 1. pull（--rebase 防与 cron roll / Codex 冲突；用探测 IP；网络类重试上限 2 次）
for i in 1 2; do
  best=$(pick_ip)
  if [ -n "$best" ]; then
    RESOLVE=$(resolve_for "$best")
    out=$(timeout 60 git -c "http.https://github.com/.curloptResolve=$RESOLVE" pull --rebase origin main 2>&1); rc=$?
  else
    out=$(timeout 60 git pull --rebase origin main 2>&1); rc=$?
  fi
  echo "$out" | tail -1
  [ $rc -eq 0 ] && break
  # rebase 停在冲突态 → 立即 abort 报错，绝不强制覆盖
  if git rev-parse -q --verify REBASE_HEAD >/dev/null 2>&1; then
    git rebase --abort >/dev/null 2>&1
    echo "REBASE_CONFLICT: pull --rebase 合并冲突，已中止并保留本地数据，需人工处理"
    exit 1
  fi
  echo "pull 失败(exit $rc，网络类)，5s 后重试 ($i/2)"
  sleep 5
done
[ $rc -eq 0 ] || { echo "PULL_FAILED: 网络类失败 2 次，停止（非 Git 历史问题，稍后重跑）"; exit 1; }

# 1b. pull 成功后恢复被暂存的本地改动（stash 分支；pop 冲突即停下人工处理）
if [ "$STASHED" = "1" ]; then
  popout=$(git stash pop 2>&1); prc=$?
  echo "$popout" | tail -1
  if [ $prc -ne 0 ]; then
    echo "STASH_POP_CONFLICT: 暂存恢复冲突（改动仍在 git stash list），需人工处理"
    exit 1
  fi
  STASHED=0
  echo "已恢复暂存的本地改动"
fi

# 2. push 前强制检查：本地领先 origin 的提交里不得出现 market/ 文件（旧路径只跳转，禁更新）
if git diff --name-only origin/main...HEAD 2>/dev/null | grep -q '^market/'; then
  echo "ABORT: 本地提交包含 market/ 文件，禁止推送，请先排查"
  git diff --name-only origin/main...HEAD
  exit 1
fi

# 3. 提交前校验 JSON（有改动才校验并提交）
if ! git diff --quiet -- data.json 2>/dev/null; then
  if ! validate_json; then
    echo "ABORT: data.json 校验未通过，禁止提交（详见 /tmp/push-validate.log）"
    tail -5 /tmp/push-validate.log
    exit 1
  fi
  git add -- data.json
  git -c user.name="blackrimdol-code" -c user.email="blackrimdol@gmail.com" commit -m "$MSG" -q
  echo "committed: $MSG"
else
  echo "data.json 无改动，跳过 commit"
fi

# 4. push（有内容才跑；每次先探测当前可用 IP；探测全挂时退化为全局配置裸试）
#    ⚠️ 错误分类: rejected/non-fast-forward = Git 同步错误（远端有新提交）→ 只允许
#      fetch/rebase 一次 + 重新校验 + 重推一次；再被拒立即停止（GIT_DESYNC）。
#      其余（curl 28/超时/不可达）= 网络错误 → 换 IP 重试，上限 ATTEMPTS 次。
PUSHED=0
REBASED=0
if [ "$(git rev-list --count origin/main..HEAD 2>/dev/null)" = "0" ] && git diff --quiet -- data.json 2>/dev/null; then
  echo "无待推送内容，跳过 push"
  PUSHED=1
else
  for i in $(seq 1 "$ATTEMPTS"); do
    best=$(pick_ip)
    if [ -n "$best" ]; then
      RESOLVE=$(resolve_for "$best")
      out=$(timeout 60 git -c "http.https://github.com/.curloptResolve=$RESOLVE" push origin main 2>&1); rc=$?
      echo "$out" | tail -1
      if [ $rc -eq 0 ]; then
        echo "PUSH_OK attempt=$i via $best"; PUSHED=1; break
      fi
      # —— Git 同步错误分支：只处理一次 ——
      if echo "$out" | grep -qiE 'rejected|non-fast-forward|Updates were rejected'; then
        if [ "$REBASED" = "1" ]; then
          echo "GIT_DESYNC: rebase 后推送仍被拒（远端持续有新提交），立即停止，需人工排查"
          exit 1
        fi
        echo "远端有本地没有的提交（non-fast-forward，Git 同步错误），fetch+rebase 一次"
        pullout=$(timeout 60 git -c "http.https://github.com/.curloptResolve=$RESOLVE" pull --rebase origin main 2>&1); prc=$?
        echo "$pullout" | tail -2
        if [ $prc -ne 0 ]; then
          if git rev-parse -q --verify REBASE_HEAD >/dev/null 2>&1; then
            git rebase --abort >/dev/null 2>&1
            echo "REBASE_CONFLICT: rebase 合并冲突，已中止并保留本地数据，需人工处理"
          else
            echo "GIT_DESYNC: rebase 拉取失败(exit $prc)，立即停止，需人工排查"
          fi
          exit 1
        fi
        REBASED=1
        # rebase 后: 重新校验 JSON + 重新做 market 安全检查
        if ! git diff --quiet -- data.json 2>/dev/null && ! validate_json; then
          echo "ABORT: rebase 后 data.json 校验未通过，停止（详见 /tmp/push-validate.log）"
          tail -5 /tmp/push-validate.log
          exit 1
        fi
        if git diff --name-only origin/main...HEAD 2>/dev/null | grep -q '^market/'; then
          echo "ABORT: rebase 后本地领先提交包含 market/ 文件，禁止推送"
          exit 1
        fi
        # 重推一次（规范允许的唯一一次重试）
        out2=$(timeout 60 git -c "http.https://github.com/.curloptResolve=$RESOLVE" push origin main 2>&1); rc=$?
        echo "$out2" | tail -1
        if [ $rc -eq 0 ]; then
          echo "PUSH_OK attempt=$i (rebase后) via $best"; PUSHED=1; break
        fi
        if echo "$out2" | grep -qiE 'rejected|non-fast-forward|Updates were rejected'; then
          echo "GIT_DESYNC: rebase 后重推仍被拒，立即停止，需人工排查"
          exit 1
        fi
        # 重推失败且非 rejected → 落入下方网络类重试
      fi
      echo "push 失败(exit $rc，网络类，走 $best)，重新探测重试 ($i/$ATTEMPTS)"
    else
      echo "候选 IP 全部不可达，退化为全局配置裸试 ($i/$ATTEMPTS)"
      timeout 60 git push origin main 2>&1 | tail -1
      rc=${PIPESTATUS[0]}
      if [ $rc -eq 0 ]; then
        echo "PUSH_OK attempt=$i (全局配置)"; PUSHED=1; break
      fi
      echo "裸试也失败(exit $rc，网络类)"
    fi
    sleep 5
  done
fi
[ $PUSHED -eq 1 ] || { echo "PUSH_FAILED — 网络类失败 $ATTEMPTS 次均未成功（上限已到，禁止继续循环），稍后重跑本脚本"; exit 1; }

# 5. 验证远端同步
timeout 60 git fetch origin main --quiet 2>/dev/null
if git status -sb | grep -q 'ahead'; then
  echo "STILL_AHEAD — 推送未成功"
  git status -sb
  exit 1
else
  echo "SYNCED"
  git status -sb
fi

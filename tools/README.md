# tools/ — 减脂看板数据维护脚本（随仓库携带）

> 这些脚本原来放在 Hermes VPS 的 `~/.hermes/scripts/`，VPS 停机后**已复制进仓库**，路径均已改为**可移植**（不再依赖任何绝对路径）。
> 全部在**仓库根目录**执行。

## 清单

| 脚本 | 用途 | 用法 |
|---|---|---|
| `update-calorie-data.py` | 写 `records` / `macros` / `intake` / `meta`；`--roll` 重算趋势窗口 | `python3 tools/update-calorie-data.py --date 2026-09-14 --records '[...]' --macros '{...}'` |
| `validate-calorie-data.py` | 提交前硬约束校验（唯一日期、禁用 0 代替未知、updatedAt 必更） | `python3 tools/validate-calorie-data.py data.json` |
| `push-data.sh` | **通用安全推送**（pull→校验→只 add data.json→commit→push→验同步） | `bash tools/push-data.sh "9-14 晚餐：xxx（1180大卡，全天2532）"` |
| `git-push-retry.sh` | 国内出口限流环境下的强化推送（IP 钉 + 错误分类 + 重试上限） | `bash tools/git-push-retry.sh "提交信息"` |
| `audit-missing-days.py` | 缺账盘点（最近 N 天缺哪些字段） | `python3 tools/audit-missing-days.py data.json 10` |

## 数据文件路径解析顺序

`update-calorie-data.py` / `validate-calorie-data.py` 按以下顺序找 `data.json`：

1. 环境变量 `CALORIE_DATA`（显式指定，最高优先）
2. **仓库根目录** `data.json`（脚本位于 `tools/`，自动向上找一级）—— 新环境默认走这条
3. `~/calorie-site/data.json`（VPS 时代的旧路径，兼容用）

所以在新环境里只要 `cd` 到仓库根目录直接跑即可，**不需要配任何东西**。

## 过渡期说明（两处脚本暂时并存）

VPS 尚未完全停机时，`~/.hermes/scripts/` 下仍是同一份脚本；两边逻辑一致，改动请**同步两边**（或直接以仓库里这份为准）。

## 推送：用哪个？

- **网络正常**（本机在境外 / 网络通畅）→ `bash tools/push-data.sh "..."`，够用且干净。
- **国内网络**（github.com 链路间歇性限流，表现为 `curl 28` / `Operation too slow`）→ `bash tools/git-push-retry.sh "..."`，它内置候选 IP 探测 + `curloptResolve` 钉 IP + `lowSpeedLimit` 快速失败。
  - 该脚本里的候选 IP 来自 2026-08-29 实测，**IP 会随 GitHub 路由变动失效**。若集体失效：逐 IP 用
    `curl -s -o /dev/null -w '%{http_code}' --resolve github.com:443:<IP> https://github.com/`
    验证出 `200` 的才可用（注意：**TCP 通不代表 TLS/HTTP 层通**，必须实测 HTTP 200），然后把可用 IP 放到数组首位。
  - 两边脚本都可选环境变量：`ATTEMPTS`（网络类重试上限，默认 3）。

## 退出码约定

- `validate-calorie-data.py`：`0` = 可提交（输出 `VALIDATION_OK`）；`1` = 致命错误（输出 `FATAL: ...` + `VALIDATION_FAILED`），**禁止提交推送**。
- `push-data.sh` / `git-push-retry.sh`：看到 `PUSH_OK` + `SYNCED` 才算成功。出现
  `ABORT` / `STILL_AHEAD` / `GIT_DESYNC` / `REBASE_CONFLICT` / `PUSH_FAILED` → **停下排查，不要继续重试**。

## 注意

- **`index.html` 不归数据维护方管**（归 Codex）；这些脚本只碰 `data.json`。
- `git add` 只允许 `git add -- data.json`；**禁止 `git add -A`**；禁止 force push。
- 详细规则与纪律见仓库根目录 `HANDOFF.md`。

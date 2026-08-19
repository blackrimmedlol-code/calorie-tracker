# 美股策略台数据维护指南

线上页面：`https://blackrimmedlol-code.github.io/calorie-tracker/market/`

页面是纯静态 GitHub Pages：`index.html` 负责渲染，`data.json` 由 19:30 盘前任务与 23:00 盘中任务更新。不要改动仓库根目录的卡路里 `data.json`。

## 写入规则

1. 更新前先读取 `market/data.json`，保留另一时段的数据。
2. 盘前任务只替换 `premarket`，盘中任务只替换 `intraday`。
3. 同步更新 `meta.updatedAt`、`meta.latestSession`、`meta.sessionDate`、`meta.nextUpdate`。
4. 不可靠的数字填 `null`，周期状态填 `unknown`；不得编造价格、指标或来源。
5. `snapshot` 最多 6 项，固定优先级为 SPY、QQQ、SOXX、DRAM、MSTR、BTC。
6. `news` 仅保留 3–5 条真正影响价格的信息；外链必须指向实际来源。
7. 每次更新直接提交到 `main`，GitHub Pages 通常 1–2 分钟后生效。

## 枚举

- `tone`: `up | down | flat`
- `timeframes`: `bull | bear | neutral | unknown`
- 矩阵信号：`+ | 0 | -`
- `latestSession`: `premarket | intraday`

## 质量检查

- JSON 可解析，且未覆盖另一时段内容。
- 盘中版必须复核 19:30 判断，不得只是重复新闻。
- 盘中 DRAM/MSTR 必须写 15m/30m/1h/4h；不可可靠获取则明确 `unknown`。
- DRAM 的消息与价格一致性、MSTR 的 BTC-MSTR 背离必须进入 `verdict` 或 `priceAction`。
- 页面只用于信息整理，不输出确定性买卖建议。

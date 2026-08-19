# 美股策略台数据维护指南

线上页面：`https://blackrimmedlol-code.github.io/calorie-tracker/market/`

页面是纯静态 GitHub Pages：`index.html` 负责渲染，`data.json` 由 19:30 盘前任务与 23:00 盘中任务更新。不要改动仓库根目录的卡路里 `data.json`。

## 写入规则

1. 更新前先读取 `market/data.json`，保留另一时段、`sourceGroups` 和历史 `reviews`。
2. 盘前任务只替换 `premarket`，盘中任务只替换 `intraday`。
3. 同步更新 `meta.updatedAt`、`meta.latestSession`、`meta.sessionDate`、`meta.nextUpdate`。
4. 不可靠的具体数字填 `null`，不得编造价格、指标或来源；周期方向可以依据真实 OHLC 聚合或结构推断，但必须在 `timeframeMethods` 和 `timeframeNotes` 说明方法与证据。
5. `snapshot` 最多 6 项，固定优先级为 SPY、QQQ、SOXX、DRAM、MSTR、BTC。
6. `news` 仅保留 3–5 条真正影响价格的信息；外链必须指向实际来源。
7. `reviews` 最新在前，最多保留 10 条；样本不足 5 条时不得展示命中率。
8. 每次更新直接提交到 `main`，GitHub Pages 通常 1–2 分钟后生效。

## 五周期规则

DRAM 与 MSTR 固定写入 `15m / 30m / 1h / 4h / 1d`，不得因为某个平台没有现成 4h 图而跳过。

- 15m、30m、1h：优先直接读取对应 K 线。
- 4h：优先直接 4h K 线；其次聚合连续四根 1h K 线；再其次结合小时结构、当日 OHLC 和前 3–5 个交易日日线判断。
- 1d：使用日线 OHLC，并参考最近 5–20 个交易日的高低点、收盘位置、均线或结构。
- 若使用聚合或结构判断，不得虚构 RSI、MACD、EMA 等未实际取得的数值。

`timeframeMethods` 枚举：

- `direct`：直接周期行情
- `aggregate`：低周期 OHLC 聚合
- `structure`：多日/多周期结构推断
- `daily`：日线 OHLC

## 数据源梯队

- 行情 / K 线：交易所、基金官网 → TradingView、Barchart、Nasdaq、Yahoo Finance 等交叉验证。
- 宏观 / 波动：美联储、美国财政部、FRED、CME FedWatch、Cboe VIX、Reuters。
- DRAM：Roundhill 官方持仓，Micron、SK Hynix、Samsung、SanDisk/Kioxia IR，TrendForce/DRAMeXchange。
- MSTR / BTC：Strategy IR 与 SEC，BTC 多市场价格，现货 ETF 资金流，IBIT/COIN 相对表现。
- 任何付费墙、延迟数据或不完整交易日必须在来源边界中说明。

## 复盘逻辑

- 23:00：复核当天 19:30 判断，分别记录市场、DRAM、MSTR 的“原判断 → 实际表现 → 确认/部分确认/失效”。
- 下一交易日 19:30：用前一交易日收盘数据完成最终复盘，并写入有效驱动、失效假设和模型调整。
- 判断错误要直接写“失效”，不能用模糊措辞回避。
- 历史最新在前；相同日期与阶段应更新原条目，不重复追加。

## 枚举

- `tone`: `up | down | flat`
- `timeframes`: `bull | bear | neutral | unknown`
- 复盘结果：`确认 | 部分确认 | 失效`
- 矩阵信号：`+ | 0 | -`
- `latestSession`: `premarket | intraday`

## 质量检查

- JSON 可解析，且未覆盖另一时段内容或复盘历史。
- 盘中版必须复核 19:30 判断，不得只是重复新闻。
- DRAM/MSTR 五周期字段完整，4h 与 1d 有方法和证据说明。
- DRAM 的消息与价格一致性、MSTR 的 BTC-MSTR 背离必须进入 `verdict` 或 `priceAction`。
- 复盘区包含至少一个明确的模型调整，不输出小样本伪精度。
- 页面只用于信息整理，不输出确定性买卖建议。

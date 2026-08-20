# 美股策略台数据维护指南 · v4

线上页面：`https://blackrimmedlol-code.github.io/calorie-tracker/market/`

页面是纯静态 GitHub Pages：`index.html` 负责渲染，`data.json` 由 19:30 盘前任务与 23:00 盘中任务更新。不要改动仓库根目录的卡路里 `data.json`。

## 写入规则

1. 更新前先读取 `market/data.json`，保留另一时段、`sourceGroups` 和历史 `reviews`。
2. 盘前任务只替换 `premarket`，盘中任务只替换 `intraday`；两者都要维护自己的 `horizons`、`macroFramework`、`expectationGaps` 与 `odds`。
3. 同步更新 `meta.updatedAt`、`meta.latestSession`、`meta.sessionDate`、`meta.nextUpdate`。
4. 不可靠的具体数字填 `null`，不得编造价格、指标或来源；周期方向可以依据真实 OHLC 聚合或结构推断，但必须在 `timeframeMethods` 和 `timeframeNotes` 说明方法与证据。
5. `snapshot` 最多 6 项，固定优先级为 SPY、QQQ、SOXX、DRAM、MSTR、BTC。
6. `news` 仅保留 3–5 条真正影响价格的信息；外链必须指向实际来源。
7. `reviews` 最新在前，最多保留 20 条；短线复盘样本不足 20 条时不得展示命中率。
8. 根级 `mediumLedger` 是 1–6 周论点账本，保留历史状态，不随盘中噪音整表覆盖；只有因果证据变化时新增、降级、关闭或更新条目。
9. 每次更新直接提交到 `main`，GitHub Pages 通常 1–2 分钟后生效。

## 双周期操作卡

每个时段的 `horizons` 固定包含 `MARKET / DRAM / MSTR`，每个对象分别包含：

- `short`：0–3 个交易日，字段为 `bias / confidence / posture / driver / trigger / invalidation`。
- `medium`：1–6 周，字段为 `bias / posture / driver / trigger / invalidation`。

短线优先级固定为：价格确认与关键位 > 跨资产/行业广度 > 事件预期差 > 宏观先验。中期优先看宏观/行业因果链、日线与周线结构、资金流和供给约束。

`posture` 使用可执行语言，例如：`突破跟随 / 等回踩 / 只按反弹看 / 不追高 / 降低隔夜权限 / 允许小仓隔夜`。不要写确定性买卖指令，也不要用一个 0–100 黑箱分数代替证据。

## 高善文式宏观因果框架

`macroFramework.pillars` 固定四项：增长、通胀、流动性/信用、风险定价。每项写：

- `state / direction`：当前状态和方向；
- `evidence`：可验证的广泛观察；
- `transmission`：从宏观变量到资产价格的传导机制；
- `invalidation`：排除证据或失效条件。

`macroFramework.chain` 写 2–5 条真正影响当日判断的因果链：`from → through → to → verdict`。宏观框架只负责方向偏向、风险预算和是否允许隔夜，不直接充当入场信号；盘中价格可以推翻盘前宏观先验。

`expectationGaps` 只收录有明确“市场先验 / 实际发生 / 价格反应 / 持仓含义”的事件，不能把普通新闻列表复制进来。

`odds` 只在取得真实历史序列时计算。页面展示的是“参考收盘价在窗口内所有收盘价中的位置分位”，不是收益率分位：

`percentile = (低于参考价的样本数 + 0.5 × 等于参考价的样本数) ÷ 样本数 × 100`

- 60 日分位：短线延伸与均值回归风险；
- 252 日分位：中期所处位置；
- 每条必须写 `asOf / referencePrice / sampleSize / basis / source`；历史 K 线有延迟，不得称为盘中现价；
- `percentile` 无法可靠计算时必须为 `null`；
- 新基金不足 252 个交易日时，不得把上市以来样本冒充 252 日。只有能从发行文件确认核心持仓、且成份股有完整日线时，才允许输出显式标记 `proxy:true` 的核心持仓代理；同时保留基金自身上市以来的样本数与分位；
- 只有进入前/后 10%，同时出现新催化，并被反转或突破确认，才升级为交易信号。

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

- 行情 / K 线：WeStock / 腾讯自选股用于结构化日线和历史窗口计算；交易所、基金官网优先校验，TradingView、Barchart、Nasdaq、Yahoo Finance 补充分时与小时行情。
- 宏观 / 波动：美联储、美国财政部、FRED、CME FedWatch、Cboe VIX、Reuters。
- DRAM：Roundhill 官方持仓，Micron、SK Hynix、Samsung、SanDisk/Kioxia IR，TrendForce/DRAMeXchange。
- MSTR / BTC：Strategy IR 与 SEC，BTC 多市场价格，现货 ETF 资金流，IBIT/COIN 相对表现。
- 期权 / 仓位：Cboe、CME、Nasdaq 期权链及可靠成交/未平仓数据；缺少完整序列时不得虚构 gamma、IV 或挤压结论。
- 跨资产 / 广度：2Y/10Y/30Y、DXY、VIX、油金、行业广度、SOXX 与同业价格；用于验证传导链而不是堆数字。
- 任何付费墙、延迟数据或不完整交易日必须在来源边界中说明。

## 复盘逻辑

- 23:00：复核当天 19:30 判断，分别记录市场、DRAM、MSTR 的“原判断 → 实际表现 → 确认/部分确认/失效”。
- 下一交易日 19:30：用前一交易日收盘数据完成最终复盘，并写入有效驱动、失效假设和模型调整。
- 判断错误要直接写“失效”，不能用模糊措辞回避。
- 短线复盘回答“今天错在哪一环”；中期账本回答“1–6 周的因果论点是否仍成立”。
- 历史最新在前；相同日期与阶段应更新原条目，不重复追加。满 20 条短线样本前只展示样本数，不展示命中率。

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
- `MARKET / DRAM / MSTR` 的短线与中期字段完整，触发和失效不能互相矛盾。
- 四个宏观支柱、至少两条因果链与预期差板块有真实证据；没有事件时允许空数组，不能凑数。
- 60/252 日价格位置分位必须能追溯到真实日线、日期和样本数；代理必须标明成份、权重口径和基金自身可用样本，不得与实际基金历史混写。
- DRAM 的消息与价格一致性、MSTR 的 BTC-MSTR 背离必须进入 `verdict` 或 `priceAction`。
- 复盘区包含至少一个明确的模型调整；`mediumLedger` 只有证据变化时才更新，不输出小样本伪精度。
- 页面只用于信息整理，不输出确定性买卖建议。

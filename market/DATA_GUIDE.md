# 美股策略台数据维护指南 · v7

线上页面：`https://blackrimmedlol-code.github.io/calorie-tracker/market/`

页面是纯静态 GitHub Pages：`index.html` 负责渲染，`data.json` 由四个策略任务更新。美东 09:00 建立先验（北京时间夏令时 21:00、冬令时 22:00）、北京时间 23:00 初次价格复核、02:00 午后盘再验证、美国收盘时最终收口。不要改动仓库根目录的卡路里 `data.json`。

> 收盘以美东时间 16:00 为准：美国夏令时对应中国时间 04:00，冬令时对应 05:00。任务必须服从“收盘”而不是全年写死 04:00。

## 写入规则

重点标的唯一排序常量：`TARGET_ORDER = ["DRAM", "LITE", "SPCX", "MSTR"]`。动作板、快照、watchlist、分位、信号矩阵、复盘和中期账本只要同时出现这些标的，都必须按此顺序输出；市场基准可放在它们之前，BTC 等联动资产可放在之后。

1. 更新前先读取 `market/data.json`，保留其他三个时段、`sourceGroups`、`reviews`、`mediumLedger` 和未知字段。
2. 四个任务只替换各自对象：09:00 ET=`premarket`、23:00=`intraday`、02:00=`late`、收盘=`close`。每个时段都维护自己的 `horizons`、`macroFramework`、`expectationGaps` 与 `odds`。
3. 同步更新 `meta.updatedAt`、`meta.latestSession`、`meta.sessionDate`、`meta.nextUpdate`。
4. 不可靠的具体数字填 `null`，不得编造价格、指标或来源；周期方向可以依据真实 OHLC 聚合或结构推断，但必须在 `timeframeMethods` 和 `timeframeNotes` 说明方法与证据。
5. `snapshot` 最多 8 项，固定优先级为 SPY、QQQ、SOXX、DRAM、LITE、SPCX、MSTR、BTC；股票/ETF 默认写正式时段最新价，不能把盘后价伪装成正式收盘。延长交易统一写入 `extendedHours`。
6. `news` 仅保留 3–5 条真正影响价格的信息；外链必须指向实际来源。
7. `reviews` 最新在前，最多保留 20 条；短线复盘样本不足 20 条时不得展示命中率。
8. 根级 `mediumLedger` 是 1–6 周论点账本，保留历史状态，不随盘中噪音整表覆盖；只有因果证据变化时新增、降级、关闭或更新条目。
9. 每次更新直接提交到 `main`，GitHub Pages 通常 1–2 分钟后生效。

## 四时段链路与 nextUpdate

| 时段对象 | 名义时间 | 核心职责 | `meta.nextUpdate` |
|---|---:|---|---|
| `premarket` | 美东 09:00（北京夏令时 21:00 / 冬令时 22:00） | 建立可证伪先验、事件表与盘前风险预算 | 当日 23:00 |
| `intraday` | 中国时间 23:00 | 用开盘后价格初验盘前判断 | 次日 02:00 |
| `late` | 中国时间 02:00 | 检查午后延续/反转、量价和关键位 | 当日美股收盘 |
| `close` | 美东 16:00 | 用完整日线最终收口、更新复盘 | 下一美股交易日 09:00 ET |

- 每个时段必须写 `available:true / updatedAt / updateStatus / sessionContext`。未生成的时段写 `available:false`，页面会禁用，不能借用其他时段快照伪装成有效数据。
- `updateStatus` 使用 `按时更新 / 延迟补跑 / 数据不完整`。实际执行时间偏离名义时点时必须写清楚，不能只保留名义标签。
- 每个时段写 `deltaLabel` 和 `changes`，固定覆盖市场、DRAM、LITE、SPCX、MSTR。字段：`asset / from / to / reason / tone`，只写相对上一有效时段真正改变的判断。

## 数据时效与价格地图

每个时段固定写 `freshness`：

- `quotes`：盘前/盘中/收盘行情的实际 `asOf`；
- `timeframes`：15m/30m/1h/4h 的获取或聚合时点；
- `daily`：日线与分位数据的截止交易日，不能和盘中现价混写；
- `macro`：宏观信息的截止时点。

每个可用时段应尽量维护 `extendedHours`，标的顺序固定为 DRAM、LITE、SPCX、MSTR。每条包含：

- `symbol / session / price / regularClose / changePct / tone`；
- `asOf / status / source / sourceUrl`；
- `state / note / nextConfirmation`。

延长交易必须分清三个口径：

- `盘后`：16:00–20:00 ET，可使用统一可审计的交易所/UTP/Cboe/S&P Global 报价；
- `夜盘`：20:00–04:00 ET，通常来自经纪商或替代交易系统，只有同时写清提供商、成交时点和报价状态时才能展示；
- `盘前`：04:00–09:30 ET，必须与前一晚盘后锚点分开。

不得把 20:00 ET 的盘后收口继续标成“当前夜盘价”，也不得把单一经纪商的稀疏打印当成全市场统一价格。没有可审计夜盘价时，保留最近可验证盘后锚点并写清边界；价格地图可用 `status:"verified"` 的最新延长交易价，但标题必须显示对应 session。盘后/夜盘突破只能提高下一正式时段的确认优先级，不能单独升级为完整交易信号。

DRAM、LITE、SPCX、MSTR 的 watchlist 项必须额外写，并按 `TARGET_ORDER` 排序：

- `priceStatus`：例如 `盘中价 · 23:00`、`收盘价 · 04:00`；
- `supportValue / resistanceValue`：用于计算现价到一级支撑、阻力的距离；对应文字仍放在 `support / resistance`；
- 结构化数值必须与文字价位一致。支撑或阻力为区间时，用最近、最可执行的一侧作为 value，并在文字中保留完整区间。

## 双周期操作卡

每个时段的 `horizons` 固定包含 `MARKET / DRAM / LITE / SPCX / MSTR`，每个对象分别包含：

- `permissions`：`chase / overnight / beta`，把宏观框架压缩为追价权限、隔夜权限和 beta 预算；

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
- SPCX 存在代码换主：旧的 SPAC and New Issue ETF 已于 2026-04-07 改为 SPCK，SpaceX 自 2026-06-12 才以 SPCX 上市。SPCX 的历史序列必须从 2026-06-12 重启，剔除旧 ETF 以及 IPO 前无成交的占位记录。样本不足 60/252 时仍可展示“上市后位置”，但必须写 `sampleNote` 和真实 `sampleSize`，不得把 47 根样本包装成完整窗口；
- 只有进入前/后 10%，同时出现新催化，并被反转或突破确认，才升级为交易信号。

## 五周期规则

DRAM、LITE、SPCX、MSTR 固定写入 `15m / 30m / 1h / 4h / 1d`，不得因为某个平台没有现成 4h 图而跳过。

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
- LITE：Lumentum IR 与 SEC 为公司事实源；云厂商 CapEx、AI 数据中心光连接需求、COHR 和光模块链用于验证行业广度与相对强弱。
- SPCX：SpaceX IR 与 SEC、Nasdaq 为身份和公司事实源；发射节奏、Starlink 运营、政府/商业订单、AI 业务资本开支与成交量用于验证。严禁使用旧 SPCX ETF 历史；旧基金只可用于解释代码换主。
- MSTR / BTC：Strategy IR 与 SEC，BTC 多市场价格，现货 ETF 资金流，IBIT/COIN 相对表现。
- 期权 / 仓位：Cboe、CME、Nasdaq 期权链及可靠成交/未平仓数据；缺少完整序列时不得虚构 gamma、IV 或挤压结论。
- 跨资产 / 广度：2Y/10Y/30Y、DXY、VIX、油金、行业广度、SOXX 与同业价格；用于验证传导链而不是堆数字。
- 任何付费墙、延迟数据或不完整交易日必须在来源边界中说明。

## 复盘逻辑

- 23:00：初次复核 09:00 ET 盘前判断。
- 02:00：只记录相对 23:00 新出现的延续、反转或关键位破坏，不重复整份新闻。
- 收盘：用完整日线最终复核当天判断，写入有效驱动、失效假设和模型调整；相同交易日的盘中复盘可以保留，但阶段必须不同。
- 下一交易日 09:00 ET：引用上一收盘复盘建立新先验，不重复造一份同义复盘。
- 复盘资产顺序固定为市场、DRAM、LITE、SPCX、MSTR。首次加入而没有上期判断时标为“新基线”，不倒填胜负；从下一有效时段起必须正常复核。
- 判断错误要直接写“失效”，不能用模糊措辞回避。
- 短线复盘回答“今天错在哪一环”；中期账本回答“1–6 周的因果论点是否仍成立”。
- 历史最新在前；相同日期与阶段应更新原条目，不重复追加。满 20 条短线样本前只展示样本数，不展示命中率。

## 枚举

- `tone`: `up | down | flat`
- `timeframes`: `bull | bear | neutral | unknown`
- 复盘结果：`确认 | 部分确认 | 失效 | 新基线`
- 矩阵信号：`+ | 0 | -`
- `latestSession`: `premarket | intraday | late | close`
- `updateStatus`: `按时更新 | 延迟补跑 | 数据不完整`

## 质量检查

- JSON 可解析，且未覆盖另一时段内容或复盘历史。
- 当前任务只改自己的时段对象；空时段保持 `available:false`，不能回退到其他时段的快照。
- 市场、DRAM、LITE、SPCX、MSTR 的 `changes` 完整，四个重点标的严格按 `TARGET_ORDER` 排序；每个数据模块都有实际时点和状态标签。
- DRAM、LITE、SPCX、MSTR 同时具有 `supportValue / resistanceValue / priceStatus`，距离计算方向正确。
- `extendedHours` 如存在，严格按 `TARGET_ORDER`，正式收盘与盘后/夜盘不混写；每条都有 session、时点、状态和来源，页面关键位距离采用的价格口径可见。
- 四时段的 `nextUpdate` 连续衔接；收盘任务使用美东 16:00，自动适配夏令时。
- 盘中版必须复核 09:00 ET 盘前判断，不得只是重复新闻。
- DRAM/LITE/SPCX/MSTR 五周期字段完整，4h 与 1d 有方法和证据说明。
- `MARKET / DRAM / LITE / SPCX / MSTR` 的短线与中期字段完整，触发和失效不能互相矛盾。
- 四个宏观支柱、至少两条因果链与预期差板块有真实证据；没有事件时允许空数组，不能凑数。
- 60/252 日价格位置分位必须能追溯到真实日线、日期和样本数；代理必须标明成份、权重口径和基金自身可用样本，不得与实际基金历史混写。
- DRAM 的消息—价格一致性、LITE 的公司—光通信链确认、SPCX 的上市后量价与代码换主隔离、MSTR 的 BTC-MSTR 背离必须进入 `verdict` 或 `priceAction`。
- 复盘区包含至少一个明确的模型调整；`mediumLedger` 只有证据变化时才更新，不输出小样本伪精度。
- 页面只用于信息整理，不输出确定性买卖建议。

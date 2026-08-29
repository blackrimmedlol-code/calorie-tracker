# Hermes 数据维护指南

> 适用于 `blackrimmedlol-code/calorie-tracker`。Hermes 是 `data.json` 的唯一写入者；页面代码由 Codex 维护。

## 每次更新前

1. 执行 `git pull --ff-only`。
2. 阅读仓库根目录的 `AGENTS.md`。
3. 按 UTC+8 的真实日期更新 `data.json`，日期格式为 `YYYY-MM-DD`。
4. 同一天只保留一个 `days` 对象；新信息合并到已有日期，不能重复创建。
5. 更新 `meta.updatedAt`，验证 JSON 后再提交和推送。

## 每日数据结构

```json
{
  "date": "2026-08-16",
  "intake": 2321,
  "records": [],
  "macros": null,
  "activity": {},
  "body": {}
}
```

只保留实际收到的数据。未知字段应省略或使用 `null`，不能用 `0` 代替“未提供”。

## 饮食

```json
{
  "name": "牛排",
  "calories": 410,
  "meal": "午餐",
  "time": "12:30"
}
```

- `time` 可选，格式为 `HH:mm`；页面会据此显示首餐和末餐。
- 同一食物或同一餐次的补充信息应合并，避免重复计入热量。

三大营养素格式：

```json
"macros": {
  "protein": 143,
  "carbs": 188,
  "fat": 112
}
```

## Apple Fitness 每日整体数据

```json
"activity": {
  "source": "Apple Fitness",
  "capturedAt": "2026-08-15T23:59:00+08:00",
  "isFinal": true,
  "activeCalories": 337,
  "totalCalories": 2230,
  "exerciseMinutes": 15,
  "standHours": 11,
  "steps": 3755,
  "distanceKm": 2.76,
  "moveGoal": 650,
  "exerciseGoal": 30,
  "standGoal": 12,
  "workouts": []
}
```

### 热量口径

- `activeCalories`：苹果“活动”大卡。
- `totalCalories`：活动页面中的“共 XXXX 大卡”，即当前或全天累计总消耗。
- 页面使用 `intake - totalCalories` 计算能量差。
- `totalCalories` 已包含基础消耗和活动消耗，禁止再次加上 `activeCalories` 或单次运动热量。
- 没有 `totalCalories` 时页面自动使用 `meta.tdee` 估算，Hermes 不需要填入估算值。

### 完整状态

- 过去日期的完整数据，或用户明确表示当天结束：`isFinal: true`。
- 当天尚未结束的截图：`isFinal: false`，并准确填写 `capturedAt`。
- 用户通常在晚上发送活动数据；仍应以截图时间和用户说明判断，不能默认所有当天截图均为最终数据。

## 单次运动

单次运动写入对应日期的 `activity.workouts`：

```json
{
  "name": "户外步行",
  "startTime": "21:42",
  "endTime": "22:48",
  "durationMin": 66,
  "distanceKm": 1.78,
  "activeCalories": 139,
  "totalCalories": 251,
  "averageHeartRate": 94,
  "averagePace": "37′07″/公里",
  "elevationGainM": 78,
  "effort": 2,
  "effortLabel": "轻松"
}
```

- 单次运动主要展示 `activeCalories`。
- 单次运动的 `totalCalories` 只用于详情展示，不参与全天能量差计算。
- 只有单次运动截图时，不得反推全天活动、步数或总消耗。
- 后续收到同一天的整体活动截图时，合并整体字段并保留已有 `workouts`。
- 按运动日期、开始时间和类型检查重复项。

## 体重

```json
"body": {
  "weightKg": 75.4,
  "measuredAt": "08:15",
  "source": "Apple Health"
}
```

- 单位统一为公斤。
- 未提供体重时不得猜测。
- 同一天多次称重时优先采用用户指定值；未指定时采用早晨空腹值。
- 页面自动计算近 30 天趋势和 7 日移动平均，Hermes 不需要计算均线。

## 缺失数据的含义

- 没有 `activity`：活动数据尚未记录。
- `"workouts": []`：明确没有专项运动或为休息日。
- 只有活动或体重、没有饮食时，可创建对应日期并设置 `intake: null`、`records: []`、`macros: null`。
- 不要创建空的 `activity: {}` 或 `body: {}`。

## 日期检查

每日整体截图和单次运动截图可能来自不同日期。必须分别读取截图顶部日期，不能因为用户同时发送而合并。

当前待写入的两组数据：

### 2026-08-15 整体活动

将以下字段合并进已有的 `2026-08-15`：

```json
"activity": {
  "source": "Apple Fitness",
  "capturedAt": "2026-08-15T23:59:00+08:00",
  "isFinal": true,
  "activeCalories": 337,
  "totalCalories": 2230,
  "exerciseMinutes": 15,
  "standHours": 11,
  "steps": 3755,
  "distanceKm": 2.76,
  "moveGoal": 650,
  "exerciseGoal": 30,
  "standGoal": 12,
  "workouts": []
}
```

### 2026-08-16 单次运动

将前述“户外步行”对象加入已有 `2026-08-16` 的 `activity.workouts`。目前没有 8 月 16 日整体活动截图，因此不要填写当天整体 `activeCalories`、`totalCalories`、步数或站立小时。

## 提交前检查

- JSON 语法有效。
- 日期正确且没有重复日期。
- 没有重复食物或重复运动。
- 单次运动没有被加到全天总消耗。
- 未知值没有被写成 0。
- `meta.updatedAt` 已更新。
- 提交前再次执行 `git pull`，再 commit/push。

更新完成后，回复用户：记录日期、饮食摄入、整体活动、单次运动、体重，以及哪些字段仍未提供。

## 仓库隔离与推送失败处理（硬性约束）

- 只允许更新 `blackrimmedlol-code/calorie-tracker` 的根目录 `data.json`。美股策略台已迁移至 `blackrimmedlol-code/us-market-dashboard`，Hermes 不得读取、写入或回退更新该市场仓库。
- 每轮必须在生成数据前同步远端；禁止基于长期未同步的本地副本直接提交。
- `non-fast-forward`、rejected、SHA/历史分叉属于 Git 同步错误，不是 CDN 或网络错误。出现时重新 fetch/rebase 并保留最新卡路里数据，最多重试推送一次；不得进入多轮网络重试。
- `curl 28`、连接超时等才归类为网络错误；网络重试也必须有上限，禁止 60 轮循环。
- 最稳妥的执行顺序：同步远端 → 写入并校验 `data.json` → 提交 → 推送；若远端在提交后变化，则 rebase 一次并重新验证后推送。


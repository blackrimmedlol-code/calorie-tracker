# 卡路里观察看板 · 项目交接说明

> 本文件由项目维护方（Hermes 大总管）编写，供 Codex / Claude Code / 其他 AI 代理接手时自动加载。

## 仓库边界（硬性约束）

- 美股策略台已迁移到独立仓库 `blackrimmedlol-code/us-market-dashboard`，线上地址为 https://blackrimmedlol-code.github.io/us-market-dashboard/ 。
- 本仓库只维护卡路里页面根目录的 `index.html` 与 `data.json`；禁止在本仓库写入任何市场数据。
- 旧 `market/` 路径仅作为迁移跳转/历史归档，不再由任何自动任务更新。

## 项目是什么

**16-8 减脂卡路里观察看板**——一个纯静态单页数据看板，展示用户每日热量摄入、目标区间、三大营养素、16-8 进食窗口和 7 天趋势。

- 线上地址：https://blackrimmedlol-code.github.io/calorie-tracker/
- 托管方式：GitHub Pages（main 分支根目录，push 后约 1-2 分钟自动生效）
- 页面语言：中文（用户为中文使用者）

## 目录结构

```
├── index.html   # 单文件应用（HTML+CSS+JS 全部内联，无构建步骤）
└── data.json    # 数据文件（页面运行时 fetch 加载，失败自动回退内置数据）
```

## 技术要点

- **图表库**：ECharts 5，国内 CDN 加载（BootCDN 主源 → staticfile.org 备用），勿改回 jsdelivr（国内访问不稳定）
- **数据加载**：页面启动 `fetch('data.json')`（`cache: no-store`），成功用远程数据渲染，失败回退内置数据
- **无构建、无依赖安装**：改完直接 commit + push 即生效
- **移动端优先**：max-width 640px 居中单栏布局

## 设计语言（重要，改样式前必读）

瑞士国际主义风格（Style B）：

- 锚点色：**克莱因蓝 IKB `#002FA7`**（用户明确指定，禁止换回绿色或其他颜色）
- 底色：米白 `#fafaf8` + 细点阵背景（radial-gradient）
- 文字：近黑 `#0a0a0a`；辅助灰 `#f0f0ee / #d4d4d2 / #737373`
- 字体：无衬线（Inter/Helvetica + PingFang SC/Noto Sans SC），元数据用等宽 mono
- 风格：直角（无圆角）、细边框、大字号对比、uppercase 小标签（kicker）
- 蓝色背景上的文字必须用白色（`--accent-on`）

CSS 变量集中在 `:root`（--paper/--ink/--grey-1~3/--accent/--accent-on），JS 图表配色变量在脚本顶部（ACCENT/INK/GREY_2/GREY_3）。

## 数据格式（data.json）

```json
{
  "meta": { "targetLow": 1600, "targetHigh": 1800, "tdee": 2090, "updatedAt": "..." },
  "days": [
    { "date": "2026-08-15", "intake": 950,
      "records": [ { "name": "米饭", "calories": 230, "meal": "午餐" } ],
      "macros": { "protein": 80, "carbs": 85, "fat": 35 } }
  ],
  "trend": [
    { "date": "08-10", "intake": null },
    { "date": "08-15", "intake": 950 },
    { "date": "今日", "intake": null }
  ]
}
```

- `trend` 为最近 7 天滚动窗口，**无记录的天 intake 必须为 null**（页面显示断点，勿填 0 或示例值）
- 页面按浏览器本地日期判断"今日是否有记录"（`days` 最后一条的 date），无记录时显示"今日尚未记录"

## 分工规则（重要）

| 职责 | 归属 |
|------|------|
| **代码/页面**（index.html：样式、图表、功能、布局） | Codex 可自由修改 |
| **数据文件**（data.json：每日摄入记录） | Hermes 大总管维护，**Codex 不要直接改** |

数据更新流程（由 Hermes 负责）：用户发餐 → 养生 agent 计算 → 脚本写入 data.json → git push → 线上自动更新。

**定时任务**：每日 0:00（北京时间）有 cron 自动滚动 trend 窗口并提交 data.json——如果你在改代码，**commit/push 前务必先 `git pull`**，避免与每日滚动提交冲突。

## 硬性约束

- ❌ 不要加回"记录一餐"表单/输入功能——用户明确要求页面为**纯观察看板**
- ❌ 不要改锚点色（IKB 蓝 #002FA7 是用户指定）
- ❌ 不要引入构建工具/框架（保持单文件静态页）
- ✅ 保持中文界面、移动端友好
- ✅ 改完用浏览器实测再提交（尤其 ECharts 初始化、fetch 逻辑）

#!/usr/bin/env python3
"""校验 calorie-tracker 根目录 data.json 是否符合 HERMES_DATA_GUIDE.md 硬性约束。

用法:
  python3 validate-calorie-data.py [data.json 路径]   # 默认 ~/calorie-site/data.json

退出码:
  0 = 通过，可提交/推送
  1 = 致命错误（禁止提交/推送，输出 FATAL 原因）

覆盖的指南约束:
  - JSON 语法有效
  - 同一天只保留一个 days 对象（日期唯一）
  - 同一食物/同餐次不得重复计入
  - 未知数据不得用 0 代替（intake=0 且无记录/活动/体重 = 疑似占位）
  - meta.updatedAt 必更（且应为北京时间 +08:00，仅告警）
  - trend 无记录天必须 null，勿填 0（仅告警）
"""
import json
import os
import sys
from pathlib import Path

def _resolve_default_path() -> Path:
    """路径解析顺序: $CALORIE_DATA > 仓库根目录 data.json > ~/calorie-site/data.json"""
    env = os.environ.get("CALORIE_DATA")
    if env:
        return Path(env).expanduser()
    repo_root = Path(__file__).resolve().parent.parent
    if (repo_root / "data.json").exists() or (repo_root / "index.html").exists():
        return repo_root / "data.json"
    return Path.home() / "calorie-site" / "data.json"


path = Path(sys.argv[1]) if len(sys.argv) > 1 else _resolve_default_path()

errors: list[str] = []
warns: list[str] = []

try:
    data = json.loads(path.read_text(encoding="utf-8"))
except Exception as exc:
    print(f"FATAL: data.json 不是合法 JSON: {exc}")
    sys.exit(1)

meta = data.get("meta") or {}
if not isinstance(meta, dict) or not meta.get("updatedAt"):
    errors.append("meta.updatedAt 缺失（指南：每次更新必须刷新）")

days = data.get("days") or []
if not isinstance(days, list):
    errors.append("days 必须是数组")
    days = []

dates = [d.get("date") for d in days]
if len(dates) != len(set(dates)):
    errors.append("days 存在重复日期（指南：同一天只保留一个 days 对象）")
if dates != sorted(dates):
    warns.append("days 未按日期升序排列（不影响提交，建议排序）")

for d in days:
    date = d.get("date")
    recs = d.get("records") or []
    intake = d.get("intake")
    # 重复食物：同名+同餐次+同热量
    seen = set()
    for r in recs:
        key = (r.get("name"), r.get("meal"), r.get("calories"))
        if key in seen:
            errors.append(f"{date}: 重复记录「{r.get('name')}」（同名同餐次同热量）")
        seen.add(key)
    # 疑似用 0 代替未知
    if intake == 0 and not recs and not d.get("activity") and not d.get("body"):
        errors.append(f"{date}: intake=0 且无 records/activity/body——疑似用 0 代替未知（指南：未知用 null 省略）")
    if isinstance(d.get("body"), dict) and d["body"].get("weightKg") == 0:
        errors.append(f"{date}: body.weightKg=0（未知体重不得写 0）")
    # 明细之和与 intake 一致性（仅告警，macros 不参与）
    if recs and isinstance(intake, (int, float)):
        s = sum(r.get("calories", 0) for r in recs)
        if abs(s - intake) > 1:
            warns.append(f"{date}: records 热量之和 {s} ≠ intake {intake}（如需修正请人工确认）")

trend = data.get("trend") or []
if not isinstance(trend, list):
    errors.append("trend 必须是数组")
else:
    for t in trend:
        if t.get("intake") == 0:
            warns.append(f"trend {t.get('date')}: intake=0（指南：无记录天必须 null，勿填 0）")

upd = meta.get("updatedAt", "")
if upd and "+08:00" not in upd:
    warns.append(f"meta.updatedAt 非北京时间(+08:00)：{upd}")

for w in warns:
    print(f"WARN: {w}")
if errors:
    for e in errors:
        print(f"FATAL: {e}")
    print("VALIDATION_FAILED")
    sys.exit(1)

print("VALIDATION_OK")
sys.exit(0)

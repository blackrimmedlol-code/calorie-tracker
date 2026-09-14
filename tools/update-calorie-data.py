#!/usr/bin/env python3
"""更新卡路里数据文件 data.json（可移植版，随仓库携带）。

用法（在仓库根目录）:
  # 追加某天记录（合并进已有日期，自动重算 intake）:
  python3 tools/update-calorie-data.py --date 2026-09-14 \
    --records '[{"name":"卤肉饭","calories":480,"meal":"晚餐"}]' \
    --macros '{"protein":63,"carbs":38,"fat":38}'
  # 只更新今日摄入汇总（无明细）:
  python3 tools/update-calorie-data.py --date 2026-09-14 --intake 1200
  # 每日滚动趋势窗口:
  python3 tools/update-calorie-data.py --roll

⚠️ 本脚本只支持 records / macros / intake / meta / --roll。
   activity（Apple Fitness / 单次运动）与 body（体重）不支持，请用 python 直改 data.json，
   字段口径见 HERMES_DATA_GUIDE.md。

路径解析顺序: $CALORIE_DATA > 仓库根目录 data.json > ~/calorie-site/data.json
"""
import argparse
import json
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path


def resolve_data_path() -> Path:
    env = os.environ.get("CALORIE_DATA")
    if env:
        return Path(env).expanduser()
    # tools/ 在仓库根目录下 → 向上找一级
    repo_root = Path(__file__).resolve().parent.parent
    candidate = repo_root / "data.json"
    if candidate.exists():
        return candidate
    if (repo_root / "index.html").exists():  # 仓库存在但还没 data.json
        return candidate
    return Path.home() / "calorie-site" / "data.json"


DATA_PATH = resolve_data_path()


def load():
    if DATA_PATH.exists():
        return json.loads(DATA_PATH.read_text(encoding="utf-8"))
    return {"meta": {}, "days": [], "trend": []}


def save(data):
    data["meta"]["updatedAt"] = datetime.now().astimezone().isoformat(timespec="seconds")
    DATA_PATH.parent.mkdir(parents=True, exist_ok=True)
    DATA_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--date", help="日期 YYYY-MM-DD（--roll 模式可省略）")
    ap.add_argument("--intake", type=float, help="当日摄入总大卡（可选，有 records 时自动重算）")
    ap.add_argument("--records", help="JSON 数组：本日食物记录")
    ap.add_argument("--mode", choices=["append", "replace"], default="append",
                    help="records 写入模式：append=按名称合并(默认) / replace=整体替换当日记录")
    ap.add_argument("--macros", help='JSON 对象：{"protein":g,"carbs":g,"fat":g}（全天汇总，非增量）')
    ap.add_argument("--meta", help='JSON 对象：{"targetLow":..,"targetHigh":..,"tdee":..}')
    ap.add_argument("--roll", action="store_true",
                    help="每日滚动模式：趋势窗口锚定今天（无记录的天留空），不新增记录")
    args = ap.parse_args()

    data = load()

    if args.meta:
        data.setdefault("meta", {}).update(json.loads(args.meta))

    # 找或建当日记录（--roll 模式不建新记录）
    if args.date:
        day = next((d for d in data["days"] if d["date"] == args.date), None)
        if day is None:
            day = {"date": args.date, "intake": 0, "records": []}
            data["days"].append(day)

        if args.records:
            recs = json.loads(args.records)
            if args.mode == "replace":
                day["records"] = recs
            else:
                existing = {r["name"]: r for r in day.get("records", [])}
                for r in recs:
                    existing[r["name"]] = r          # 同名会被覆盖：同名不同菜请改名字
                day["records"] = list(existing.values())
            day["intake"] = sum(r["calories"] for r in day["records"])

        if args.intake is not None:
            day["intake"] = round(float(args.intake))

        if args.macros:
            day["macros"] = json.loads(args.macros)   # 整体覆盖，全天汇总请自行累加后传入
    elif not args.roll:
        ap.error("--date 或 --roll 必须提供其一")

    # 趋势：最近 7 天滚动窗口（真实记录，无记录的天留空 = null）
    data["days"].sort(key=lambda d: d["date"])
    if data["days"] or args.roll:
        anchor = datetime.now().strftime("%Y-%m-%d") if args.roll else (
            data["days"][-1]["date"] if data["days"] else None)
        if anchor:
            by_date = {d["date"]: d for d in data["days"]}
            trend = []
            for i in range(6, 0, -1):
                d = datetime.strptime(anchor, "%Y-%m-%d") - timedelta(days=i)
                ds = d.strftime("%Y-%m-%d")
                hist_day = by_date.get(ds)             # 注意变量名：勿用 day，会覆盖当日记录
                trend.append({"date": d.strftime("%m-%d"),
                              "intake": hist_day["intake"] if hist_day else None})
            today_day = by_date.get(anchor)
            trend.append({"date": "今日", "intake": today_day["intake"] if today_day else None})
            data["trend"] = trend

    save(data)
    if args.roll:
        print(f"ROLL {DATA_PATH} | 趋势窗口锚定 {datetime.now().strftime('%Y-%m-%d')}")
    else:
        print(f"OK {DATA_PATH} | {args.date} intake={day['intake']} 大卡")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""缺账盘点：扫 calorie-tracker 的 data.json，列出最近 N 天缺哪些字段。

用户长期没更新后常一次性发多天数据并要求「帮我看哪天没记」——直接跑这个，
不要手工翻 JSON。

用法:
    python3 audit-missing-days.py [data.json 路径] [天数，默认 10]
    # 例: python3 audit-missing-days.py ~/calorie-site/data.json 14

输出: 每个有缺口的日期 + 缺什么（饮食/活动/体重）+ 该日已有的部分（便于回复用户
      「9-10 活动已记，缺三餐」这种信息），末尾给最后记录日统计。
"""
import datetime
import json
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "data.json"
n = int(sys.argv[2]) if len(sys.argv) > 2 else 10

d = json.load(open(path, encoding="utf-8"))
by = {x["date"]: x for x in d.get("days", [])}
today = datetime.date.today()
start = today - datetime.timedelta(days=n - 1)

print(f"updatedAt {d.get('meta', {}).get('updatedAt')} | 今日 {today} | 窗口 {start} ~ {today}")

gaps = 0
cur = start
while cur <= today:
    s = cur.isoformat()
    x = by.get(s)
    if x is None:
        miss = ["整天无记录"]
        note = ""
    else:
        miss = []
        if not x.get("records"):
            miss.append("饮食")
        if not x.get("activity"):
            miss.append("活动")
        if not x.get("body"):
            miss.append("体重")
        a = x.get("activity") or {}
        parts = []
        if a:
            parts.append(f"活动已记 {a.get('activeCalories')}大卡/{a.get('steps')}步")
        if x.get("records"):
            parts.append(f"饮食已记 {x.get('intake')}大卡({len(x['records'])}条)")
        if x.get("body"):
            parts.append(f"体重已记 {x['body'].get('weightKg')}kg")
        note = ("  ← " + "；".join(parts)) if parts else ""
    if miss:
        gaps += 1
        print(f"  ❌ {s} 缺: {'、'.join(miss)}{note}")
    cur += datetime.timedelta(days=1)

if not gaps:
    print("  ✅ 窗口内无缺口")

# 各字段最后一次记录的日期，方便回复「体重最后一次是 x-xx」
def last_where(pred):
    hits = sorted(k for k, v in by.items() if pred(v))
    return hits[-1] if hits else "无"

print("最后记录日 —— 饮食:", last_where(lambda v: v.get("records")),
      "| 活动:", last_where(lambda v: v.get("activity")),
      "| 体重:", last_where(lambda v: v.get("body")))
print("提示: 「缺体重」多为用户未称重而非漏记；「缺饮食」要问清是没吃还是漏记，不要假设。")

#!/usr/bin/env python3
import json
import sys
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

def main():
    query = json.load(sys.stdin)
    date = query["date"]
    time_str = query["time"]
    tz_name = query["timezone"]

    tz = ZoneInfo(tz_name)
    local_dt = datetime.fromisoformat(f"{date}T{time_str}").replace(tzinfo=tz)
    min_local = datetime.now(tz) + timedelta(minutes=5)
    while local_dt <= min_local:
        local_dt = local_dt + timedelta(days=1)
    utc_dt = local_dt.astimezone(ZoneInfo("UTC"))
    print(json.dumps({"utc_time": utc_dt.strftime("%Y-%m-%dT%H:%M:%SZ")}))

if __name__ == "__main__":
    main()

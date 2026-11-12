# AKS stop schedules

`daily_stop_times` retains the existing list interface and derives schedule IDs from HHMM.
To preserve existing schedule names and runbook bindings when adopting changed times, supply
`daily_stop_times_by_id`, for example `{ "1800" = "19:00", "2359" = "00:00" }`, and
`schedule_timezone = "America/Chicago"`. Keep these IDs stable after adoption.

The existing `start_time` lifecycle exclusion remains: adopting a changed wall-clock time on an
existing schedule requires a separately verified Azure start-time update. This input records its
desired local time, computes initial creation times and reconciles description/timezone; it does
not silently reset an existing schedule's first execution date. Verify Azure `nextRun` as part of
any existing-schedule time change.

Run the offline provider-mocked contracts with `tofu init -backend=false` and `tofu test`.

{% docs stg_engineering_prs %}
**Grain: one row per pull request.** Typed copy of the raw PR export, with the derived fields the marts need.
- `is_merged` is true when `merged_at` is set. Unmerged PRs keep their row but have no lead time.
- `lead_time_minutes` is minutes from `created_at` to `merged_at`, NULL when unmerged.
- `merge_week_start` is the Monday of the merge week (ISO), used to bucket merged PRs.
- No rows are dropped and no values are changed here.
{% enddocs %}

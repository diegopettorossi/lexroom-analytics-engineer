{% docs fct_pr_lead_time_weekly %}
**Grain: one row per team per ISO week of merge.** Bonus mart for engineering health, reading the `raw_engineering_prs` seed directly.

**Lead time:** hours from PR opened (`created_at`) to PR merged (`merged_at`). Reported as median and p90.

This is a **proxy** for DORA lead time for changes. DORA measures commit to production. This measures PR opened to merged, so it leaves out time spent before the PR is opened and time between merge and deploy.

**Not covered:** deployment frequency and change failure rate. The extract has no deploy or incident data.

**Scope rules:**
- Team level only. No per-author figures, so the metric cannot rank engineers.
- Unmerged PRs are excluded, since they have no lead time yet.
- The week in progress is never shown (`anchor_week(0)`).
- A team-week with fewer than `min_merged_prs_for_signal` (5) merges is kept but flagged `is_lead_time_reliable = false`.
{% enddocs %}

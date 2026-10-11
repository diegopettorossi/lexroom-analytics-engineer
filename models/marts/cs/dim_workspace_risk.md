{% docs dim_workspace_risk %}
**Grain: one row per workspace (all of them).** Every row is scored against the same window, stamped in the `as_of_date` and `last_completed_week` columns. Customer Success starts here: sort by `risk_score` and read the signal columns to see why an account is flagged.

It compares the last `period_weeks` weeks with the same number of weeks before.

**Risk score, 0 to 100:** each signal is scaled against its full-alarm level, capped at 1, then weighted:
- usage decline vs the platform: weight 0.50, full alarm at 50% of volume lost relative to the platform
- satisfaction drop: weight 0.50, full alarm at a 20 percentage-point drop (stored as 0.20)

Weights and full-alarm levels are the `risk_signals` var. Tiers come from `risk_tiers`. A workspace with fewer than `min_events_for_risk` answers in the prior period is `not_scored`, because small accounts swing too much to rank.

Only two signals are used on purpose. Usage and satisfaction are the ones this extract can support. Hallucination and latency stay on the quality mart. Adding them here would need evidence that they predict churn, which this data cannot show.
{% enddocs %}

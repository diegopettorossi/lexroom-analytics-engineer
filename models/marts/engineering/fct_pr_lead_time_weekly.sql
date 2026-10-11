-- One team per ISO week of merge. Lead time = PR opened to PR merged, a proxy for DORA lead time for changes.
-- Unmerged PRs have no lead time and are left out; the week in progress is never shown.
SELECT
    team,
    merge_week_start AS week_start,
    COUNT(*) AS merged_prs,
    ROUND(MEDIAN(lead_time_minutes) / 60.0, 1) AS median_lead_time_hours,
    ROUND(QUANTILE_CONT(lead_time_minutes, 0.9) / 60.0, 1) AS p90_lead_time_hours,
    COUNT(*) >= {{ var('min_merged_prs_for_signal') }} AS is_lead_time_reliable
FROM {{ ref('stg_engineering_prs') }}
WHERE is_merged
  AND merge_week_start <= {{ anchor_week(0) }}
GROUP BY team, week_start

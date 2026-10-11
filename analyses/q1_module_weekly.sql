-- Q1: weekly AQI per module over the last 8 completed weeks.
-- quality_index comes from fct_ama_module_weekly, so this series uses the same formula as the 4-week comparison.
-- Read rated_events next to the index: several module-weeks have too few ratings to treat the move as real.
SELECT
    module_tag,
    week_start,
    events,
    rated_events,
    quality_index,
    ROUND(
        quality_index - LAG(quality_index) OVER (PARTITION BY module_tag ORDER BY week_start),
        1
    ) AS quality_index_wow_change
FROM {{ ref('fct_ama_module_weekly') }}
WHERE
    week_start > {{ anchor_week(var('weeks_window')) }}
    AND week_start <= {{ anchor_week() }}
ORDER BY module_tag, week_start

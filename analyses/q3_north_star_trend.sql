-- Q3: company-wide AQI by week. Built from the module mart, with rates recomputed from summed
-- counts so it always matches Q1 (rates are never averaged across modules).
WITH weekly AS (

    SELECT
        week_start,
        SUM(events) AS events,
        SUM(rated_events) AS rated_events,
        SUM(thumbs_up) AS thumbs_up,
        SUM(grounded_events) AS grounded_events,
        SUM(fresh_events) AS fresh_events,
        SUM(slow_events) AS slow_events
    FROM {{ ref('fct_ama_module_weekly') }}
    WHERE
        week_start > {{ anchor_week(var('weeks_window')) }}
        AND week_start <= {{ anchor_week() }}
    GROUP BY week_start

),

rates AS (

    SELECT
        *,
        rated_events * 1.0 / events AS feedback_coverage,
        thumbs_up * 1.0 / NULLIF(rated_events, 0) AS satisfaction_rate,
        grounded_events * 1.0 / events AS grounded_rate,
        1 - slow_events * 1.0 / NULLIF(fresh_events, 0) AS fast_rate
    FROM weekly

),

scored AS (

    SELECT
        *,
        {{ aqi('satisfaction_rate', 'grounded_rate', 'fast_rate') }} AS quality_index
    FROM rates

)

SELECT
    week_start,
    events,
    rated_events,
    ROUND(feedback_coverage, 3) AS feedback_coverage,
    ROUND(satisfaction_rate, 3) AS satisfaction_rate,
    ROUND(grounded_rate, 3) AS grounded_rate,
    ROUND(fast_rate, 3) AS fast_rate,
    quality_index,
    ROUND(quality_index - LAG(quality_index) OVER (ORDER BY week_start), 1) AS quality_index_wow_change,
    rated_events >= {{ var('min_rated_high_confidence') }} AS is_high_confidence
FROM scored
ORDER BY week_start

-- Q1: AQI per module, last 4 weeks (recent) vs the 4 before (prior). Biggest declines first.
WITH periods AS (

    SELECT
        module_tag,
        week_start >= {{ anchor_week(var('period_weeks') - 1) }} AS is_recent,
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
    GROUP BY module_tag, is_recent

),

rates AS (

    SELECT
        *,
        thumbs_up * 1.0 / NULLIF(rated_events, 0) AS satisfaction_rate,
        grounded_events * 1.0 / events AS grounded_rate,
        1 - slow_events * 1.0 / NULLIF(fresh_events, 0) AS fast_rate
    FROM periods

),

scored AS (

    SELECT
        *,
        {{ aqi('satisfaction_rate', 'grounded_rate', 'fast_rate') }} AS quality_index
    FROM rates

)

SELECT
    r.module_tag,
    r.events AS events_recent,
    r.rated_events AS rated_recent,
    ROUND(p.satisfaction_rate, 3) AS satisfaction_prior,
    ROUND(r.satisfaction_rate, 3) AS satisfaction_recent,
    p.quality_index AS aqi_prior,
    r.quality_index AS aqi_recent,
    ROUND(r.quality_index - p.quality_index, 1) AS aqi_change
FROM scored AS r
INNER JOIN scored AS p ON r.module_tag = p.module_tag AND NOT p.is_recent
WHERE r.is_recent
ORDER BY aqi_change ASC

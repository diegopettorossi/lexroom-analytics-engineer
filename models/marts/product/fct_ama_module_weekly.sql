WITH weekly_counts AS (

    SELECT
        module_tag,
        week_start,
        COUNT(*) AS events,
        COUNT(*) FILTER (WHERE has_feedback) AS rated_events,
        COUNT(*) FILTER (WHERE thumbs = 1) AS thumbs_up,
        COUNT(*) FILTER (WHERE NOT is_zero_retrieval) AS grounded_events,
        COUNT(*) FILTER (WHERE fresh_latency_ms IS NOT NULL) AS fresh_events,
        COUNT(*) FILTER (WHERE fresh_latency_ms > {{ var('slow_latency_ms') }}) AS slow_events
    FROM {{ ref('int_ama_event_enriched') }}
    GROUP BY module_tag, week_start

),

rates AS (

    SELECT
        *,
        thumbs_up * 1.0 / NULLIF(rated_events, 0) AS satisfaction_rate,
        grounded_events * 1.0 / events AS grounded_rate,
        1 - slow_events * 1.0 / NULLIF(fresh_events, 0) AS fast_rate
    FROM weekly_counts

)

SELECT
    module_tag,
    week_start,
    events,
    rated_events,
    thumbs_up,
    grounded_events,
    fresh_events,
    slow_events,
    ROUND(rated_events * 1.0 / events, 3) AS feedback_coverage,
    ROUND(satisfaction_rate, 3) AS satisfaction_rate,
    ROUND(grounded_rate, 3) AS grounded_rate,
    ROUND(fast_rate, 3) AS fast_rate,
    {{ aqi('satisfaction_rate', 'grounded_rate', 'fast_rate') }} AS quality_index,
    rated_events >= {{ var('min_rated_for_signal') }} AS is_satisfaction_reliable
FROM rates

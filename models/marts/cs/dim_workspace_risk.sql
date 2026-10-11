WITH bounds AS (

    SELECT
        {{ anchor_week() }} AS current_week,
        {{ anchor_week(var('period_weeks') - 1) }} AS current_start,
        {{ anchor_week(2 * var('period_weeks') - 1) }} AS prior_start

),

recent_events AS (

    SELECT
        e.workspace_id,
        e.has_feedback,
        e.thumbs,
        e.week_start >= b.current_start AS is_current
    FROM {{ ref('int_ama_event_enriched') }} AS e
    CROSS JOIN bounds AS b
    INNER JOIN {{ ref('stg_workspaces') }} AS ws ON e.workspace_id = ws.workspace_id
    WHERE e.week_start BETWEEN b.prior_start AND b.current_week

),

platform AS (

    SELECT
        COUNT(*) FILTER (WHERE is_current) * 1.0
        / NULLIF(COUNT(*) FILTER (WHERE NOT is_current), 0) AS platform_ratio
    FROM recent_events

),

workspace_periods AS (

    SELECT
        workspace_id,
        COUNT(*) FILTER (WHERE is_current) AS cur_events,
        COUNT(*) FILTER (WHERE NOT is_current) AS pri_events,
        COUNT(*) FILTER (WHERE is_current AND has_feedback) AS cur_rated,
        COUNT(*) FILTER (WHERE NOT is_current AND has_feedback) AS pri_rated,
        COUNT(*) FILTER (WHERE is_current AND thumbs = 1) AS cur_up,
        COUNT(*) FILTER (WHERE NOT is_current AND thumbs = 1) AS pri_up
    FROM recent_events
    GROUP BY workspace_id

),

signals AS (

    SELECT
        ws.workspace_id,
        ws.country,
        ws.plan,
        ws.firm_size_bucket,
        COALESCE(p.cur_events, 0) AS events_current_period,
        COALESCE(p.pri_events, 0) AS events_prior_period,
        COALESCE(p.cur_rated, 0) AS rated_current_period,
        COALESCE(p.pri_rated, 0) AS rated_prior_period,
        COALESCE(p.pri_events, 0) >= {{ var('min_events_for_risk') }} AS is_scorable,
        GREATEST(
            0,
            1 - (COALESCE(p.cur_events, 0) * 1.0 / NULLIF(p.pri_events, 0)) / pl.platform_ratio
        ) AS usage_decline,
        CASE
            WHEN p.cur_rated >= {{ var('min_rated_for_signal') }} AND p.pri_rated >= {{ var('min_rated_for_signal') }}
                THEN GREATEST(0, p.pri_up * 1.0 / p.pri_rated - p.cur_up * 1.0 / p.cur_rated)
            ELSE 0
        END AS satisfaction_drop
    FROM {{ ref('stg_workspaces') }} AS ws
    LEFT JOIN workspace_periods AS p ON ws.workspace_id = p.workspace_id
    CROSS JOIN platform AS pl

),

scored AS (

    SELECT
        *,
        ROUND(100 * (
            {{ var('risk_signals')['usage_decline']['weight'] }}
            * LEAST(1, usage_decline / {{ var('risk_signals')['usage_decline']['full_alarm'] }})
            + {{ var('risk_signals')['satisfaction_drop']['weight'] }}
            * LEAST(1, satisfaction_drop / {{ var('risk_signals')['satisfaction_drop']['full_alarm'] }})
        ), 1) AS raw_risk_score
    FROM signals

)

SELECT
    {{ as_of_date() }} AS as_of_date,
    {{ anchor_week() }} AS last_completed_week,
    workspace_id,
    country,
    plan,
    firm_size_bucket,
    events_current_period,
    events_prior_period,
    rated_current_period,
    rated_prior_period,
    ROUND(usage_decline, 2) AS usage_decline,
    ROUND(satisfaction_drop, 2) AS satisfaction_drop,
    CASE WHEN is_scorable THEN raw_risk_score END AS risk_score,
    CASE
        WHEN NOT is_scorable THEN 'not_scored'
        WHEN raw_risk_score >= {{ var('risk_tiers')['high'] }} THEN 'high'
        WHEN raw_risk_score >= {{ var('risk_tiers')['medium'] }} THEN 'medium'
        ELSE 'low'
    END AS risk_tier
FROM scored

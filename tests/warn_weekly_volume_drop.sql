{{ config(severity='warn') }}
-- Warns when the last completed week has far fewer AMA answers than the average of the 4 weeks before it.
-- Missing weeks count as zero. A drop like this is usually an ingestion gap, not real usage.
WITH weekly AS (

    SELECT
        week_start,
        COUNT(*) AS events
    FROM {{ ref('stg_ama_events') }}
    WHERE week_start BETWEEN {{ anchor_week(var('period_weeks')) }} AND {{ anchor_week() }}
    GROUP BY week_start

),

totals AS (

    SELECT
        COALESCE(SUM(events) FILTER (WHERE week_start = {{ anchor_week() }}), 0) AS last_week_events,
        COALESCE(SUM(events) FILTER (WHERE week_start < {{ anchor_week() }}), 0) * 1.0
        / {{ var('period_weeks') }} AS prior_weekly_avg
    FROM weekly

)

SELECT *
FROM totals
WHERE last_week_events < {{ var('min_weekly_volume_ratio') }} * prior_weekly_avg

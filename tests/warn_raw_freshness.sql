{{ config(severity='warn') }}
-- Warns when the newest raw answer or rating is more than max_ingestion_lag_days older than as_of_date.
-- A stale load means the last week is incomplete, so the trend numbers for it are not final.
WITH latest AS (

    SELECT
        'ama_events' AS source_name,
        CAST(MAX(created_at) AT TIME ZONE 'UTC' AS DATE) AS latest_date
    FROM {{ ref('raw_events_ama') }}

    UNION ALL

    SELECT
        'ama_feedback' AS source_name,
        CAST(MAX(created_at) AT TIME ZONE 'UTC' AS DATE) AS latest_date
    FROM {{ ref('raw_feedback_ama') }}

),

lagged AS (

    SELECT
        source_name,
        latest_date,
        DATE_DIFF('day', latest_date, CAST({{ as_of_date() }} AS DATE)) AS lag_days
    FROM latest

)

SELECT *
FROM lagged
WHERE lag_days > {{ var('max_ingestion_lag_days') }}

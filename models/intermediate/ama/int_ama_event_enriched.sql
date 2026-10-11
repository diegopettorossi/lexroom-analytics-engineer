WITH events AS (

    SELECT * FROM {{ ref('stg_ama_events') }}

),

latest_feedback AS (

    SELECT
        event_id,
        thumbs,
        reason_tag
    FROM {{ ref('stg_ama_feedback') }}
    WHERE thumbs IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY created_at DESC) = 1

)

SELECT
    e.event_id,
    e.workspace_id,
    e.module_tag,
    e.week_start,
    (f.event_id IS NOT NULL) AS has_feedback,
    f.thumbs,
    CASE WHEN f.thumbs = -1 THEN COALESCE(f.reason_tag, 'unspecified') END AS reason_tag,
    (e.retrieved_chunks = 0) AS is_zero_retrieval,
    CASE WHEN e.is_valid_latency AND NOT e.is_cached THEN e.response_latency_ms END AS fresh_latency_ms
FROM events AS e
LEFT JOIN latest_feedback AS f ON e.event_id = f.event_id

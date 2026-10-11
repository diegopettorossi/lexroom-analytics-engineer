SELECT
    feedback_id,
    event_id,
    thumbs AS thumbs_raw,
    NULLIF(SIGN(thumbs), 0) AS thumbs,
    NULLIF(TRIM(reason_tag), '') AS reason_tag,
    CAST(created_at AT TIME ZONE 'UTC' AS TIMESTAMP) AS created_at
FROM {{ ref('raw_feedback_ama') }}
-- Exact duplicates in the raw export: keep one. The raw-level test still reports them.
QUALIFY ROW_NUMBER() OVER (PARTITION BY feedback_id ORDER BY created_at) = 1

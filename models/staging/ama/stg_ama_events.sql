WITH cleaned AS (

    SELECT
        event_id,
        workspace_id,
        REGEXP_REPLACE(LOWER(STRIP_ACCENTS(TRIM(module_tag))), '[^a-z]', '', 'g') AS module_tag,
        response_latency_ms,
        is_cached,
        retrieved_chunks,
        created_at
    FROM {{ ref('raw_events_ama') }}

)

SELECT
    event_id,
    workspace_id,
    -- One known source typo, mapped explicitly. Any new unknown tag still warns (accepted_values).
    CASE WHEN module_tag = 'civil' THEN 'civile' ELSE module_tag END AS module_tag,
    response_latency_ms,
    (
        response_latency_ms > 0
        AND response_latency_ms <= {{ var('latency_valid_max_ms') }}
    ) AS is_valid_latency,
    is_cached,
    retrieved_chunks,
    CAST(DATE_TRUNC('week', created_at AT TIME ZONE 'UTC') AS DATE) AS week_start
FROM cleaned
-- Exact duplicates in the raw export: keep one. The raw-level test still reports them.
QUALIFY ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY created_at) = 1

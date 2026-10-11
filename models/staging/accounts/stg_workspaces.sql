SELECT
    workspace_id,
    COALESCE(NULLIF(TRIM(country), ''), 'unknown') AS country,
    plan,
    firm_size_bucket
FROM {{ ref('raw_workspaces') }}

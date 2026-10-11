SELECT
    user_id,
    workspace_id,
    role,
    CAST(created_at AT TIME ZONE 'UTC' AS TIMESTAMP) AS created_at,
    is_deleted
FROM {{ ref('raw_users') }}

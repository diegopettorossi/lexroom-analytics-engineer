SELECT
    pr_id,
    team,
    author_id,
    created_at,
    merged_at,
    merged_at IS NOT NULL AS is_merged,
    CASE
        WHEN merged_at IS NOT NULL
        THEN DATE_DIFF('minute', created_at, merged_at)
    END AS lead_time_minutes,
    CAST(DATE_TRUNC('week', merged_at) AS DATE) AS merge_week_start,
    lines_added,
    lines_deleted,
    review_comments_count
FROM {{ ref('raw_engineering_prs') }}

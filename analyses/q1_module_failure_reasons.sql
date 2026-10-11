-- Q1: thumbs-down reasons per module over the last 4 weeks, most common first.
-- A thumbs-down with no reason is `unspecified` and still counts.
SELECT
    module_tag,
    reason_tag,
    COUNT(*) AS reasons
FROM {{ ref('int_ama_event_enriched') }}
WHERE
    thumbs = -1
    AND week_start >= {{ anchor_week(var('period_weeks') - 1) }}
    AND week_start <= {{ anchor_week() }}
GROUP BY module_tag, reason_tag
ORDER BY reasons DESC, module_tag ASC

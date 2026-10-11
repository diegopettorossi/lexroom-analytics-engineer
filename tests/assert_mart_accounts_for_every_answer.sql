-- Every staged AMA answer is counted exactly once in the module mart (none lost, none double counted).
WITH mart AS (

    SELECT SUM(events) AS answers
    FROM {{ ref('fct_ama_module_weekly') }}

),

staged AS (

    SELECT COUNT(*) AS answers
    FROM {{ ref('stg_ama_events') }}

)

SELECT
    mart.answers AS mart_answers,
    staged.answers AS staged_answers
FROM mart
CROSS JOIN staged
WHERE mart.answers <> staged.answers

-- Q2: workspaces to call first, with the signals behind each score.
SELECT
    workspace_id,
    plan,
    country,
    firm_size_bucket,
    risk_score,
    risk_tier,
    events_prior_period,
    events_current_period,
    usage_decline,
    satisfaction_drop
FROM {{ ref('dim_workspace_risk') }}
WHERE risk_tier IN ('high', 'medium')
ORDER BY risk_score DESC

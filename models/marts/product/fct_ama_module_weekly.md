{% docs fct_ama_module_weekly %}
**Grain: one row per legal module per week (Monday start).** Used by Product (Q1) and rolled up for leadership (Q3).

**AMA Quality Index (AQI), 0 to 100:**

`AQI = 100 x (w_satisfaction x satisfaction + w_grounded x grounded + w_fast x fast)`

- satisfaction: thumbs up / rated answers (weight 0.50)
- grounded: answers where RAG found at least one source / all answers (weight 0.25)
- fast: 1 - slow non-cached answers / non-cached answers with a trusted latency (weight 0.25)

The weights are the `aqi_weights` var in `dbt_project.yml` and must sum to 1. Satisfaction only sees the rated quarter of answers, so the other two components use every answer and balance it.

If a component cannot be computed (a week with no ratings, or no trusted latency), the index is NULL. It is not filled in with zero.
{% enddocs %}

{% docs stg_ama_feedback %}
**Grain: one row per feedback id.** Thumbs up or down given to an AMA answer.
Exact duplicate rows are collapsed to one (reported by the warn test on the raw seed). A blank `reason_tag` becomes NULL.
Ratings that point to answers we do not have are reported by a warn test; they drop out of the quality metrics when the enriched events join to ratings.
{% enddocs %}

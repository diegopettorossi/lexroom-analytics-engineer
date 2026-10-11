{% docs stg_ama_events %}
**Grain: one row per AMA answer.** Cleaned copy of the raw event stream.
- Exact duplicate rows in the export are collapsed to one. The count is reported by the warn test on the raw seed, so the problem stays visible at the source.
- The module tag is lowercased, accents and non-letters are removed, and the one known typo `civil` is mapped to `civile`. Any other value outside the official list raises a warning and is kept as-is.
- Impossible latencies are flagged, not deleted, so volume counts stay honest.
{% enddocs %}

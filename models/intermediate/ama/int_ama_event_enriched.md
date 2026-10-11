{% docs int_ama_event_enriched %}
**Grain: one row per AMA answer.** Each answer with its module, workspace, and final rating.
If an answer was rated several times, the latest rating wins, and its reason comes with it. A thumbs-down with no reason is `unspecified`. Only ratings that are valid and linked to a known answer count.
Both marts are built from this table. The Q1 failure-reason query reads `reason_tag` from here.
{% enddocs %}

{% docs stg_users %}
**Grain: one row per user.** The roster of people in a workspace: role, when they were created, and whether the account is soft-deleted.

`is_deleted` is a snapshot flag. This extract has no deletion timestamp, so the flag cannot be placed in a week and is not a churn date. Deleted users are kept. The risk score does not use this table.
{% enddocs %}

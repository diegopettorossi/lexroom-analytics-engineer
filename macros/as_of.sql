{#- Reference date. The extract is static, so as_of_date is pinned in dbt_project.yml.
    When it is null (production), the reference date is the run date. -#}
{% macro as_of_date() -%}
{%- if var('as_of_date') is none -%}CURRENT_DATE{%- else -%}DATE '{{ var("as_of_date") }}'{%- endif -%}
{%- endmacro %}

{#- Monday of the last completed ISO week, minus weeks_back weeks, as a DATE.
    The week that contains as_of_date is still in progress, so it is never used. anchor_week(0) is the last completed week. -#}
{% macro anchor_week(weeks_back=0) -%}
CAST(DATE_TRUNC('week', {{ as_of_date() }}) - INTERVAL ({{ weeks_back + 1 }}) WEEK AS DATE)
{%- endmacro %}

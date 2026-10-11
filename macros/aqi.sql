{#- AMA Quality Index, 0 to 100, from three rates (see fct_ama_module_weekly docs).
    Any missing rate makes the index NULL, so a period with no ratings is not scored as 0% satisfied. -#}
{% macro aqi(satisfaction_rate, grounded_rate, fast_rate) -%}
ROUND(100 * (
      {{ var('aqi_weights')['satisfaction'] }} * {{ satisfaction_rate }}
    + {{ var('aqi_weights')['grounded'] }}     * {{ grounded_rate }}
    + {{ var('aqi_weights')['fast'] }}         * {{ fast_rate }}
), 1)
{%- endmacro %}

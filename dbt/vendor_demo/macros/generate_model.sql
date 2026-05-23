-- =============================================================
-- generate_model.sql
-- Reads DBT_MODEL_CONFIG to dynamically build a SELECT statement
-- for any staging model registered in the config table.
--
-- Usage in a staging model:
--   {{ generate_staging_sql('STG_VENDOR_MASTER') }}
--
-- This macro demonstrates how config-driven dbt models work:
-- 1. Developer edits config/model_config.yml
-- 2. CI/CD loads it to DBT_MODEL_CONFIG via load_config_to_snowflake.py
-- 3. This macro reads DBT_MODEL_CONFIG at compile time
-- 4. dbt generates the staging SQL automatically
-- =============================================================

{% macro generate_staging_sql(target_model_name) %}

    {# Query the config table at compile time to get column list #}
    {% set config_query %}
        SELECT
            c.COLUMN_NAME,
            c.DATA_TYPE,
            c.IS_PK,
            c.IS_NULLABLE,
            c.INCLUDE_IN_MART,
            m.SOURCE_SCHEMA,
            m.SOURCE_TABLE,
            m.UNIQUE_KEY
        FROM LEARNING_DB.RAW.DBT_MODEL_CONFIG c
        JOIN LEARNING_DB.RAW.DBT_MODEL_CONFIG m
            ON c.TARGET_MODEL = m.TARGET_MODEL
            AND c.SOURCE_TABLE = m.SOURCE_TABLE
        WHERE c.TARGET_MODEL = '{{ target_model_name }}'
          AND c.IS_ACTIVE = TRUE
        GROUP BY
            c.COLUMN_NAME, c.DATA_TYPE, c.IS_PK,
            c.IS_NULLABLE, c.INCLUDE_IN_MART,
            m.SOURCE_SCHEMA, m.SOURCE_TABLE, m.UNIQUE_KEY
        ORDER BY c.IS_PK DESC, c.COLUMN_NAME ASC
    {% endset %}

    {% if execute %}
        {% set results = run_query(config_query) %}

        {% if results.rows | length == 0 %}
            {{ exceptions.raise_compiler_error(
                "generate_staging_sql: No columns found for model '"
                ~ target_model_name
                ~ "' in DBT_MODEL_CONFIG. Run scripts/load_config_to_snowflake.py first."
            ) }}
        {% endif %}

        {# Extract metadata from first row #}
        {% set source_schema = results.columns['SOURCE_SCHEMA'].values()[0] %}
        {% set source_table  = results.columns['SOURCE_TABLE'].values()[0] %}

        SELECT
            {% for row in results %}
                {% set col = row['COLUMN_NAME'] %}
                {% set dtype = row['DATA_TYPE'] %}
                {# Uppercase text columns, cast numerics/dates explicitly #}
                {% if dtype == 'VARCHAR' %}
                    UPPER(TRIM({{ col }})) AS {{ col }}
                {% elif dtype == 'NUMBER' %}
                    CAST({{ col }} AS NUMBER(15,2)) AS {{ col }}
                {% elif dtype == 'DATE' %}
                    CAST({{ col }} AS DATE) AS {{ col }}
                {% elif dtype == 'TIMESTAMP' %}
                    CAST({{ col }} AS TIMESTAMP_NTZ) AS {{ col }}
                {% else %}
                    {{ col }}
                {% endif %}
                {%- if not loop.last %},{% endif %}

            {% endfor %}
            , CURRENT_TIMESTAMP() AS dbt_loaded_at

        FROM {{ source(source_schema | lower, source_table | lower) }}

    {% endif %}

{% endmacro %}


{% macro get_model_columns(target_model_name) %}
    {# Helper: returns a list of column names for a registered model #}
    {% set query %}
        SELECT COLUMN_NAME
        FROM LEARNING_DB.RAW.DBT_MODEL_CONFIG
        WHERE TARGET_MODEL = '{{ target_model_name }}'
          AND IS_ACTIVE = TRUE
        ORDER BY IS_PK DESC, COLUMN_NAME ASC
    {% endset %}

    {% if execute %}
        {% set results = run_query(query) %}
        {{ return(results.columns['COLUMN_NAME'].values()) }}
    {% else %}
        {{ return([]) }}
    {% endif %}
{% endmacro %}


{% macro get_pk_column(target_model_name) %}
    {# Helper: returns the primary key column for a registered model #}
    {% set query %}
        SELECT COLUMN_NAME
        FROM LEARNING_DB.RAW.DBT_MODEL_CONFIG
        WHERE TARGET_MODEL = '{{ target_model_name }}'
          AND IS_PK = TRUE
          AND IS_ACTIVE = TRUE
        LIMIT 1
    {% endset %}

    {% if execute %}
        {% set results = run_query(query) %}
        {% if results.rows | length > 0 %}
            {{ return(results.columns['COLUMN_NAME'].values()[0]) }}
        {% else %}
            {{ return(none) }}
        {% endif %}
    {% else %}
        {{ return(none) }}
    {% endif %}
{% endmacro %}

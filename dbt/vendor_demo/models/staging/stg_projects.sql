{{
    config(
        materialized = 'view',
        schema = 'STAGING'
    )
}}

-- Staging model for PROJECTS.
-- Standardizes text, casts types, adds derived budget/schedule/deadline metrics.

SELECT
    UPPER(TRIM(PROJECT_ID))          AS PROJECT_ID,
    UPPER(TRIM(PROJECT_NAME))        AS PROJECT_NAME,
    UPPER(TRIM(CLIENT_NAME))         AS CLIENT_NAME,
    UPPER(TRIM(PROJECT_TYPE))        AS PROJECT_TYPE,
    UPPER(TRIM(LOCATION))            AS LOCATION,
    UPPER(TRIM(PROJECT_MANAGER))     AS PROJECT_MANAGER,
    CAST(CONTRACT_VALUE AS NUMBER(15, 2))       AS CONTRACT_VALUE,
    CAST(BUDGET AS NUMBER(15, 2))               AS BUDGET,
    CAST(ACTUAL_COST_TO_DATE AS NUMBER(15, 2))  AS ACTUAL_COST_TO_DATE,
    CAST(START_DATE AS DATE)                    AS START_DATE,
    CAST(EXPECTED_END_DATE AS DATE)             AS EXPECTED_END_DATE,
    CAST(ACTUAL_END_DATE AS DATE)               AS ACTUAL_END_DATE,
    UPPER(TRIM(STATUS))              AS STATUS,
    CAST(COMPLETION_PCT AS NUMBER(5, 2))          AS COMPLETION_PCT,
    CAST(EXPECTED_COMPLETION_PCT AS NUMBER(5, 2)) AS EXPECTED_COMPLETION_PCT,
    UPPER(TRIM(RISK_LEVEL))          AS RISK_LEVEL,
    UPPER(TRIM(PAYMENT_TERMS))       AS PAYMENT_TERMS,
    CAST(RETAINAGE_PCT AS NUMBER(4, 2))         AS RETAINAGE_PCT,
    UPPER(TRIM(PERMIT_NUMBER))       AS PERMIT_NUMBER,
    CAST(CREATED_DATE AS DATE)                  AS CREATED_DATE,

    -- Dollar variance: positive = over budget, negative = under
    CAST(ACTUAL_COST_TO_DATE AS NUMBER(15, 2))
        - CAST(BUDGET AS NUMBER(15, 2))          AS BUDGET_VARIANCE,

    -- Percentage over/under budget
    CASE
        WHEN BUDGET IS NOT NULL AND BUDGET > 0
        THEN ROUND(
            ((CAST(ACTUAL_COST_TO_DATE AS NUMBER(15, 2)) - CAST(BUDGET AS NUMBER(15, 2)))
             / CAST(BUDGET AS NUMBER(15, 2))) * 100,
            2)
        ELSE NULL
    END AS BUDGET_VARIANCE_PCT,

    -- TRUE when actual spend has exceeded approved budget
    CASE
        WHEN CAST(ACTUAL_COST_TO_DATE AS NUMBER(15, 2)) > CAST(BUDGET AS NUMBER(15, 2))
        THEN TRUE
        ELSE FALSE
    END AS IS_OVER_BUDGET,

    -- Schedule variance: negative = behind schedule
    CAST(COMPLETION_PCT AS NUMBER(5, 2))
        - CAST(EXPECTED_COMPLETION_PCT AS NUMBER(5, 2)) AS SCHEDULE_VARIANCE_PCT,

    -- TRUE when actual completion is below expected completion
    CASE
        WHEN CAST(COMPLETION_PCT AS NUMBER(5, 2)) < CAST(EXPECTED_COMPLETION_PCT AS NUMBER(5, 2))
        THEN TRUE
        ELSE FALSE
    END AS IS_BEHIND_SCHEDULE,

    -- Days until expected project end (negative = past deadline)
    DATEDIFF('day', CURRENT_DATE(), CAST(EXPECTED_END_DATE AS DATE)) AS DAYS_TO_DEADLINE,

    -- TRUE if deadline is within 90 days
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), CAST(EXPECTED_END_DATE AS DATE)) <= 90
        THEN TRUE
        ELSE FALSE
    END AS IS_EXPIRING_SOON,

    CURRENT_TIMESTAMP() AS DBT_LOADED_AT

FROM {{ source('raw', 'projects') }}

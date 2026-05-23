{{
    config(
        materialized = 'view',
        schema = 'STAGING'
    )
}}

-- Staging model for VENDOR_MASTER.
-- Standardizes text to uppercase, adds derived metrics and expiry flags.

SELECT
    UPPER(TRIM(VENDOR_ID))          AS VENDOR_ID,
    UPPER(TRIM(VENDOR_NAME))        AS VENDOR_NAME,
    UPPER(TRIM(VENDOR_TYPE))        AS VENDOR_TYPE,
    UPPER(TRIM(COUNTRY))            AS COUNTRY,
    UPPER(TRIM(PAYMENT_TERMS))      AS PAYMENT_TERMS,
    CAST(CREDIT_LIMIT AS NUMBER(15, 2))   AS CREDIT_LIMIT,
    CAST(CONTRACT_START AS DATE)          AS CONTRACT_START,
    CAST(CONTRACT_END AS DATE)            AS CONTRACT_END,
    UPPER(TRIM(RISK_RATING))        AS RISK_RATING,
    UPPER(TRIM(ACCOUNT_MANAGER))    AS ACCOUNT_MANAGER,
    UPPER(TRIM(STATUS))             AS STATUS,
    CAST(ANNUAL_SPEND AS NUMBER(15, 2))   AS ANNUAL_SPEND,
    UPPER(TRIM(PREFERRED_CURRENCY)) AS PREFERRED_CURRENCY,

    -- Days until contract expiry (negative = already expired)
    DATEDIFF('day', CURRENT_DATE(), CAST(CONTRACT_END AS DATE)) AS CONTRACT_DAYS_REMAINING,

    -- Credit utilization: what percentage of credit limit has been consumed
    CASE
        WHEN CREDIT_LIMIT IS NOT NULL AND CREDIT_LIMIT > 0
        THEN ROUND((ANNUAL_SPEND / CREDIT_LIMIT) * 100, 2)
        ELSE NULL
    END AS CREDIT_UTILIZATION_PCT,

    -- Flag vendors whose contracts expire within 90 days
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), CAST(CONTRACT_END AS DATE)) <= 90
        THEN TRUE
        ELSE FALSE
    END AS IS_EXPIRING_SOON,

    CURRENT_TIMESTAMP() AS DBT_LOADED_AT

FROM {{ source('raw', 'vendor_master') }}

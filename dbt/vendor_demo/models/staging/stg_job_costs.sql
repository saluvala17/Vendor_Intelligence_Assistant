{{
    config(
        materialized = 'view',
        schema = 'STAGING'
    )
}}

-- Staging model for JOB_COSTS.
-- Calculates outstanding balances, overdue days, and lien risk flags.

SELECT
    UPPER(TRIM(COST_ID))             AS COST_ID,
    UPPER(TRIM(PROJECT_ID))          AS PROJECT_ID,
    CAST(COST_DATE AS DATE)                     AS COST_DATE,
    CAST(DUE_DATE AS DATE)                      AS DUE_DATE,
    UPPER(TRIM(VENDOR_NAME))         AS VENDOR_NAME,
    UPPER(TRIM(COST_TYPE))           AS COST_TYPE,
    UPPER(TRIM(CATEGORY))            AS CATEGORY,
    TRIM(DESCRIPTION)                AS DESCRIPTION,
    CAST(INVOICE_AMOUNT AS NUMBER(15, 2))       AS INVOICE_AMOUNT,
    COALESCE(CAST(PAID_AMOUNT AS NUMBER(15, 2)), 0) AS PAID_AMOUNT,
    UPPER(TRIM(STATUS))              AS STATUS,
    UPPER(TRIM(APPROVER))            AS APPROVER,
    UPPER(TRIM(PAYMENT_METHOD))      AS PAYMENT_METHOD,
    UPPER(TRIM(COST_CODE))           AS COST_CODE,
    TRIM(NOTES)                      AS NOTES,

    -- Amount still owed on this cost entry
    CAST(INVOICE_AMOUNT AS NUMBER(15, 2))
        - COALESCE(CAST(PAID_AMOUNT AS NUMBER(15, 2)), 0) AS OUTSTANDING_AMOUNT,

    -- Days past due (positive = overdue, negative = not yet due)
    DATEDIFF('day', CAST(DUE_DATE AS DATE), CURRENT_DATE()) AS DAYS_OVERDUE,

    -- Unpaid subcontractors create lien risk on the project
    CASE
        WHEN UPPER(TRIM(STATUS)) = 'OVERDUE'
        THEN TRUE
        ELSE FALSE
    END AS LIEN_RISK,

    CURRENT_TIMESTAMP() AS DBT_LOADED_AT

FROM {{ source('raw', 'job_costs') }}

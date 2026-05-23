{{
    config(
        materialized = 'view',
        schema = 'STAGING'
    )
}}

-- Staging model for VENDOR_INVOICES.
-- Calculates outstanding balances, overdue metrics, and breach flags.

SELECT
    UPPER(TRIM(INVOICE_ID))         AS INVOICE_ID,
    UPPER(TRIM(VENDOR_ID))          AS VENDOR_ID,
    CAST(INVOICE_DATE AS DATE)            AS INVOICE_DATE,
    CAST(DUE_DATE AS DATE)                AS DUE_DATE,
    CAST(INVOICE_AMOUNT AS NUMBER(15, 2)) AS INVOICE_AMOUNT,
    COALESCE(CAST(PAID_AMOUNT AS NUMBER(15, 2)), 0) AS PAID_AMOUNT,
    UPPER(TRIM(STATUS))             AS STATUS,
    UPPER(TRIM(BUSINESS_UNIT))      AS BUSINESS_UNIT,
    UPPER(TRIM(CATEGORY))           AS CATEGORY,
    UPPER(TRIM(COST_CENTER))        AS COST_CENTER,
    UPPER(TRIM(APPROVER))           AS APPROVER,
    UPPER(TRIM(PAYMENT_METHOD))     AS PAYMENT_METHOD,

    -- Amount still owed on this invoice
    CAST(INVOICE_AMOUNT AS NUMBER(15, 2))
        - COALESCE(CAST(PAID_AMOUNT AS NUMBER(15, 2)), 0) AS OUTSTANDING_AMOUNT,

    -- Days past due date (positive = overdue, negative = not yet due)
    DATEDIFF('day', CAST(DUE_DATE AS DATE), CURRENT_DATE()) AS DAYS_OVERDUE,

    -- Payment breach: overdue and more than 30 days past due
    CASE
        WHEN UPPER(TRIM(STATUS)) = 'OVERDUE'
         AND DATEDIFF('day', CAST(DUE_DATE AS DATE), CURRENT_DATE()) > 30
        THEN TRUE
        ELSE FALSE
    END AS PAYMENT_BREACH,

    CURRENT_TIMESTAMP() AS DBT_LOADED_AT

FROM {{ source('raw', 'vendor_invoices') }}

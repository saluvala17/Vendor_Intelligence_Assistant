{{
    config(
        materialized = 'table',
        schema = 'MART'
    )
}}

-- Payment-centric mart for AP workflow and approver action tracking.
-- Used for: outstanding balance analysis, payment prioritization, approver SLA.

SELECT
    inv.INVOICE_ID,
    inv.VENDOR_ID,
    inv.INVOICE_DATE,
    inv.DUE_DATE,
    inv.INVOICE_AMOUNT,
    inv.PAID_AMOUNT,
    inv.OUTSTANDING_AMOUNT,
    inv.STATUS,
    inv.BUSINESS_UNIT,
    inv.CATEGORY,
    inv.COST_CENTER,
    inv.APPROVER,
    inv.PAYMENT_METHOD,
    inv.DAYS_OVERDUE,
    inv.PAYMENT_BREACH,

    -- Payment priority: OVERDUE invoices always HIGH, large outstanding = MEDIUM
    CASE
        WHEN inv.STATUS = 'OVERDUE'                        THEN 'HIGH'
        WHEN inv.OUTSTANDING_AMOUNT > 50000                THEN 'MEDIUM'
        ELSE 'LOW'
    END AS PAYMENT_PRIORITY,

    -- Approver must act if invoice is pending and already past due date
    CASE
        WHEN inv.STATUS = 'PENDING'
         AND inv.DAYS_OVERDUE > 0
        THEN TRUE
        ELSE FALSE
    END AS APPROVER_ACTION_REQUIRED,

    inv.DBT_LOADED_AT

FROM {{ ref('stg_vendor_invoices') }} AS inv

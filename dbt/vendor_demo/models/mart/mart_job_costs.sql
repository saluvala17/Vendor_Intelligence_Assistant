{{
    config(
        materialized = 'table',
        schema = 'MART'
    )
}}

-- Payment-centric mart for job cost workflow and approver action tracking.
-- Used for: outstanding balance analysis, payment prioritization, lien risk, approver SLA.

SELECT
    jc.COST_ID,
    jc.PROJECT_ID,
    jc.COST_DATE,
    jc.DUE_DATE,
    jc.VENDOR_NAME,
    jc.COST_TYPE,
    jc.CATEGORY,
    jc.DESCRIPTION,
    jc.INVOICE_AMOUNT,
    jc.PAID_AMOUNT,
    jc.OUTSTANDING_AMOUNT,
    jc.STATUS,
    jc.APPROVER,
    jc.PAYMENT_METHOD,
    jc.COST_CODE,
    jc.DAYS_OVERDUE,
    jc.LIEN_RISK,

    -- Payment priority: OVERDUE = HIGH (lien risk), large outstanding = MEDIUM
    CASE
        WHEN jc.STATUS = 'OVERDUE'          THEN 'HIGH'
        WHEN jc.OUTSTANDING_AMOUNT > 50000  THEN 'MEDIUM'
        ELSE 'LOW'
    END AS PAYMENT_PRIORITY,

    -- Approver must act if cost entry is pending and already past due date
    CASE
        WHEN jc.STATUS = 'PENDING'
         AND jc.DAYS_OVERDUE > 0
        THEN TRUE
        ELSE FALSE
    END AS APPROVER_ACTION_REQUIRED,

    jc.DBT_LOADED_AT

FROM {{ ref('stg_job_costs') }} AS jc

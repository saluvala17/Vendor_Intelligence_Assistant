{{
    config(
        materialized = 'table',
        schema = 'MART'
    )
}}

-- 360-degree vendor view: master data joined with invoice aggregates.
-- Adds composite RISK_SCORE (1-6) and RISK_SCORE_CATEGORY.
-- Primary mart consumed by the AI chatbot.

WITH invoice_aggregates AS (
    SELECT
        VENDOR_ID,
        SUM(INVOICE_AMOUNT)                                  AS TOTAL_INVOICE_AMOUNT,
        SUM(PAID_AMOUNT)                                     AS TOTAL_PAID_AMOUNT,
        SUM(OUTSTANDING_AMOUNT)                              AS TOTAL_OUTSTANDING_AMOUNT,
        COUNT(INVOICE_ID)                                    AS INVOICE_COUNT,
        COUNT(CASE WHEN STATUS = 'OVERDUE'  THEN 1 END)     AS OVERDUE_INVOICE_COUNT,
        COUNT(CASE WHEN STATUS = 'PENDING'  THEN 1 END)     AS PENDING_INVOICE_COUNT,
        AVG(CASE WHEN STATUS = 'OVERDUE'
                 THEN DAYS_OVERDUE END)                      AS AVG_DAYS_OVERDUE,
        MAX(CASE WHEN STATUS = 'OVERDUE'
                 THEN TRUE ELSE FALSE END)                   AS HAS_OVERDUE_INVOICES
    FROM {{ ref('stg_vendor_invoices') }}
    GROUP BY VENDOR_ID
),

risk_scoring AS (
    SELECT
        vm.VENDOR_ID,
        vm.VENDOR_NAME,
        vm.VENDOR_TYPE,
        vm.COUNTRY,
        vm.PAYMENT_TERMS,
        vm.CREDIT_LIMIT,
        vm.CONTRACT_START,
        vm.CONTRACT_END,
        vm.RISK_RATING,
        vm.ACCOUNT_MANAGER,
        vm.STATUS,
        vm.ANNUAL_SPEND,
        vm.PREFERRED_CURRENCY,
        vm.CREDIT_UTILIZATION_PCT,
        vm.CONTRACT_DAYS_REMAINING,
        vm.IS_EXPIRING_SOON,

        -- Invoice aggregates (0 if no invoices)
        COALESCE(ia.TOTAL_INVOICE_AMOUNT,   0) AS TOTAL_INVOICE_AMOUNT,
        COALESCE(ia.TOTAL_PAID_AMOUNT,      0) AS TOTAL_PAID_AMOUNT,
        COALESCE(ia.TOTAL_OUTSTANDING_AMOUNT, 0) AS TOTAL_OUTSTANDING_AMOUNT,
        COALESCE(ia.INVOICE_COUNT,          0) AS INVOICE_COUNT,
        COALESCE(ia.OVERDUE_INVOICE_COUNT,  0) AS OVERDUE_INVOICE_COUNT,
        COALESCE(ia.PENDING_INVOICE_COUNT,  0) AS PENDING_INVOICE_COUNT,
        COALESCE(ia.AVG_DAYS_OVERDUE,       0) AS AVG_DAYS_OVERDUE,
        COALESCE(ia.HAS_OVERDUE_INVOICES, FALSE) AS HAS_OVERDUE_INVOICES,

        -- Composite risk score:
        --   Base risk:      HIGH=3, MEDIUM=2, LOW=1
        --   Overdue penalty:    +2 if any OVERDUE invoice
        --   Expiry penalty:     +1 if contract expires within 90 days
        (
            CASE vm.RISK_RATING
                WHEN 'HIGH'   THEN 3
                WHEN 'MEDIUM' THEN 2
                ELSE               1
            END
            + CASE WHEN COALESCE(ia.HAS_OVERDUE_INVOICES, FALSE) THEN 2 ELSE 0 END
            + CASE WHEN vm.IS_EXPIRING_SOON THEN 1 ELSE 0 END
        ) AS RISK_SCORE

    FROM {{ ref('stg_vendor_master') }} AS vm
    LEFT JOIN invoice_aggregates AS ia
        ON vm.VENDOR_ID = ia.VENDOR_ID
)

SELECT
    VENDOR_ID,
    VENDOR_NAME,
    VENDOR_TYPE,
    COUNTRY,
    PAYMENT_TERMS,
    CREDIT_LIMIT,
    CONTRACT_START,
    CONTRACT_END,
    RISK_RATING,
    ACCOUNT_MANAGER,
    STATUS,
    ANNUAL_SPEND,
    PREFERRED_CURRENCY,
    CREDIT_UTILIZATION_PCT,
    CONTRACT_DAYS_REMAINING,
    IS_EXPIRING_SOON,
    TOTAL_INVOICE_AMOUNT,
    TOTAL_PAID_AMOUNT,
    TOTAL_OUTSTANDING_AMOUNT,
    INVOICE_COUNT,
    OVERDUE_INVOICE_COUNT,
    PENDING_INVOICE_COUNT,
    AVG_DAYS_OVERDUE,
    HAS_OVERDUE_INVOICES,
    RISK_SCORE,

    -- Human-readable risk category
    CASE
        WHEN RISK_SCORE >= 5 THEN 'CRITICAL'
        WHEN RISK_SCORE >= 3 THEN 'WATCH'
        ELSE                      'STABLE'
    END AS RISK_SCORE_CATEGORY,

    CURRENT_TIMESTAMP() AS DBT_LOADED_AT

FROM risk_scoring
ORDER BY RISK_SCORE DESC, TOTAL_OUTSTANDING_AMOUNT DESC

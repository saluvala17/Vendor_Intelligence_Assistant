{{
    config(
        materialized = 'table',
        schema = 'MART'
    )
}}

-- 360-degree project view: project master joined with job-cost aggregates.
-- Adds composite RISK_SCORE (1-6) and RISK_SCORE_CATEGORY.
-- Primary mart consumed by the AI chatbot.

WITH cost_aggregates AS (
    SELECT
        PROJECT_ID,
        SUM(INVOICE_AMOUNT)                              AS TOTAL_COST_AMOUNT,
        SUM(PAID_AMOUNT)                                 AS TOTAL_PAID_AMOUNT,
        SUM(OUTSTANDING_AMOUNT)                          AS TOTAL_OUTSTANDING_AMOUNT,
        COUNT(COST_ID)                                   AS COST_ENTRY_COUNT,
        COUNT(CASE WHEN STATUS = 'OVERDUE'  THEN 1 END)  AS OVERDUE_COST_COUNT,
        COUNT(CASE WHEN STATUS = 'PENDING'  THEN 1 END)  AS PENDING_COST_COUNT,
        AVG(CASE WHEN STATUS = 'OVERDUE'
                 THEN DAYS_OVERDUE END)                  AS AVG_DAYS_OVERDUE,
        MAX(CASE WHEN STATUS = 'OVERDUE'
                 THEN TRUE ELSE FALSE END)               AS HAS_OVERDUE_COSTS
    FROM {{ ref('stg_job_costs') }}
    GROUP BY PROJECT_ID
),

risk_scoring AS (
    SELECT
        p.PROJECT_ID,
        p.PROJECT_NAME,
        p.CLIENT_NAME,
        p.PROJECT_TYPE,
        p.LOCATION,
        p.PROJECT_MANAGER,
        p.CONTRACT_VALUE,
        p.BUDGET,
        p.ACTUAL_COST_TO_DATE,
        p.START_DATE,
        p.EXPECTED_END_DATE,
        p.ACTUAL_END_DATE,
        p.STATUS,
        p.COMPLETION_PCT,
        p.EXPECTED_COMPLETION_PCT,
        p.RISK_LEVEL,
        p.PAYMENT_TERMS,
        p.RETAINAGE_PCT,
        p.PERMIT_NUMBER,
        p.BUDGET_VARIANCE,
        p.BUDGET_VARIANCE_PCT,
        p.IS_OVER_BUDGET,
        p.SCHEDULE_VARIANCE_PCT,
        p.IS_BEHIND_SCHEDULE,
        p.DAYS_TO_DEADLINE,
        p.IS_EXPIRING_SOON,

        -- Job cost aggregates (0 if no entries)
        COALESCE(ca.TOTAL_COST_AMOUNT,      0) AS TOTAL_COST_AMOUNT,
        COALESCE(ca.TOTAL_PAID_AMOUNT,      0) AS TOTAL_PAID_AMOUNT,
        COALESCE(ca.TOTAL_OUTSTANDING_AMOUNT, 0) AS TOTAL_OUTSTANDING_AMOUNT,
        COALESCE(ca.COST_ENTRY_COUNT,       0) AS COST_ENTRY_COUNT,
        COALESCE(ca.OVERDUE_COST_COUNT,     0) AS OVERDUE_COST_COUNT,
        COALESCE(ca.PENDING_COST_COUNT,     0) AS PENDING_COST_COUNT,
        COALESCE(ca.AVG_DAYS_OVERDUE,       0) AS AVG_DAYS_OVERDUE,
        COALESCE(ca.HAS_OVERDUE_COSTS, FALSE)  AS HAS_OVERDUE_COSTS,

        -- Composite risk score:
        --   Base risk:          HIGH=3, MEDIUM=2, LOW=1
        --   Over budget:        +1 if ACTUAL_COST_TO_DATE > BUDGET
        --   Behind schedule:    +1 if COMPLETION_PCT < EXPECTED_COMPLETION_PCT
        --   Lien risk:          +1 if any OVERDUE job cost (unpaid sub)
        (
            CASE p.RISK_LEVEL
                WHEN 'HIGH'   THEN 3
                WHEN 'MEDIUM' THEN 2
                ELSE               1
            END
            + CASE WHEN p.IS_OVER_BUDGET     THEN 1 ELSE 0 END
            + CASE WHEN p.IS_BEHIND_SCHEDULE THEN 1 ELSE 0 END
            + CASE WHEN COALESCE(ca.HAS_OVERDUE_COSTS, FALSE) THEN 1 ELSE 0 END
        ) AS RISK_SCORE

    FROM {{ ref('stg_projects') }} AS p
    LEFT JOIN cost_aggregates AS ca
        ON p.PROJECT_ID = ca.PROJECT_ID
)

SELECT
    PROJECT_ID,
    PROJECT_NAME,
    CLIENT_NAME,
    PROJECT_TYPE,
    LOCATION,
    PROJECT_MANAGER,
    CONTRACT_VALUE,
    BUDGET,
    ACTUAL_COST_TO_DATE,
    START_DATE,
    EXPECTED_END_DATE,
    ACTUAL_END_DATE,
    STATUS,
    COMPLETION_PCT,
    EXPECTED_COMPLETION_PCT,
    RISK_LEVEL,
    PAYMENT_TERMS,
    RETAINAGE_PCT,
    PERMIT_NUMBER,
    BUDGET_VARIANCE,
    BUDGET_VARIANCE_PCT,
    IS_OVER_BUDGET,
    SCHEDULE_VARIANCE_PCT,
    IS_BEHIND_SCHEDULE,
    DAYS_TO_DEADLINE,
    IS_EXPIRING_SOON,
    TOTAL_COST_AMOUNT,
    TOTAL_PAID_AMOUNT,
    TOTAL_OUTSTANDING_AMOUNT,
    COST_ENTRY_COUNT,
    OVERDUE_COST_COUNT,
    PENDING_COST_COUNT,
    AVG_DAYS_OVERDUE,
    HAS_OVERDUE_COSTS,
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

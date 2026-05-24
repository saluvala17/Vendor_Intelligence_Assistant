"""
Snowflake connection manager for the Vendor Intelligence chatbot.
Uses environment variables exclusively — no hardcoded credentials.
"""

import os
import streamlit as st
import snowflake.connector
import pandas as pd
from typing import Optional


class SnowflakeConnection:
    """Manages a single Snowflake connection with Streamlit caching."""

    def __init__(self):
        self._conn: Optional[snowflake.connector.SnowflakeConnection] = None

    def _get_connection(self) -> snowflake.connector.SnowflakeConnection:
        if self._conn is None or self._conn.is_closed():
            self._conn = snowflake.connector.connect(
                account=os.getenv("SNOWFLAKE_ACCOUNT"),
                user=os.getenv("SNOWFLAKE_USER"),
                password=os.getenv("SNOWFLAKE_PASSWORD"),
                warehouse=os.getenv("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH"),
                database=os.getenv("SNOWFLAKE_DATABASE", "LEARNING_DB"),
                schema=os.getenv("SNOWFLAKE_SCHEMA", "MART"),
                role=os.getenv("SNOWFLAKE_ROLE", "SYSADMIN"),
                client_session_keep_alive=True,
            )
        return self._conn

    def execute_query(self, sql: str) -> pd.DataFrame:
        conn = self._get_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(sql)
            columns = [col[0] for col in cursor.description]
            rows = cursor.fetchall()
            return pd.DataFrame(rows, columns=columns)
        finally:
            cursor.close()

    def close(self) -> None:
        if self._conn and not self._conn.is_closed():
            self._conn.close()
            self._conn = None


@st.cache_resource
def get_snowflake_connection() -> SnowflakeConnection:
    """Returns a cached Snowflake connection for the app session."""
    required = ["SNOWFLAKE_ACCOUNT", "SNOWFLAKE_USER", "SNOWFLAKE_PASSWORD"]
    missing = [v for v in required if not os.getenv(v)]
    if missing:
        raise EnvironmentError(
            f"Missing required environment variables: {missing}. "
            f"Copy .env.example to .env and add your credentials."
        )
    return SnowflakeConnection()


@st.cache_data(ttl=300)
def get_dashboard_data() -> dict:
    """Returns all chart/KPI data for the dashboard — cached 5 minutes."""
    conn = get_snowflake_connection()
    try:
        kpi = conn.execute_query("""
            SELECT
                COUNT(DISTINCT PROJECT_ID)                                    AS total_projects,
                SUM(TOTAL_OUTSTANDING_AMOUNT)                                 AS total_outstanding,
                SUM(OVERDUE_COST_COUNT)                                       AS overdue_count,
                COUNT(CASE WHEN RISK_SCORE_CATEGORY = 'CRITICAL' THEN 1 END) AS critical_count,
                COUNT(CASE WHEN IS_OVER_BUDGET = TRUE THEN 1 END)            AS over_budget_count,
                SUM(PENDING_COST_COUNT)                                       AS pending_approvals
            FROM LEARNING_DB.MART.MART_PROJECT_360
            WHERE STATUS = 'ACTIVE'
        """)

        budget_chart = conn.execute_query("""
            SELECT
                PROJECT_NAME,
                BUDGET / 1000          AS BUDGET_K,
                ACTUAL_COST_TO_DATE / 1000 AS ACTUAL_K,
                IS_OVER_BUDGET,
                RISK_SCORE_CATEGORY
            FROM LEARNING_DB.MART.MART_PROJECT_360
            WHERE STATUS = 'ACTIVE'
            ORDER BY BUDGET DESC
            LIMIT 8
        """)

        risk_chart = conn.execute_query("""
            SELECT RISK_SCORE_CATEGORY, COUNT(*) AS CNT
            FROM LEARNING_DB.MART.MART_PROJECT_360
            WHERE STATUS = 'ACTIVE'
            GROUP BY RISK_SCORE_CATEGORY
            ORDER BY CNT DESC
        """)

        pm_chart = conn.execute_query("""
            SELECT
                p.PROJECT_MANAGER,
                COUNT(jc.COST_ID)          AS PENDING_COUNT,
                SUM(jc.OUTSTANDING_AMOUNT) AS PENDING_AMOUNT
            FROM LEARNING_DB.MART.MART_JOB_COSTS jc
            JOIN LEARNING_DB.MART.MART_PROJECT_360 p ON jc.PROJECT_ID = p.PROJECT_ID
            WHERE jc.STATUS = 'PENDING'
            GROUP BY p.PROJECT_MANAGER
            ORDER BY PENDING_AMOUNT DESC
            LIMIT 5
        """)

        return {
            "kpi": kpi.iloc[0].to_dict() if not kpi.empty else {},
            "budget_chart": budget_chart,
            "risk_chart": risk_chart,
            "pm_chart": pm_chart,
        }
    except Exception:
        return {}


@st.cache_data(ttl=300)
def get_live_stats() -> dict:
    """Returns sidebar KPI stats — cached for 5 minutes."""
    conn = get_snowflake_connection()
    try:
        df = conn.execute_query("""
            SELECT
                COUNT(DISTINCT PROJECT_ID)                                   AS total_projects,
                SUM(TOTAL_OUTSTANDING_AMOUNT)                                AS total_outstanding,
                SUM(OVERDUE_COST_COUNT)                                      AS overdue_count,
                COUNT(CASE WHEN RISK_SCORE_CATEGORY = 'CRITICAL' THEN 1 END) AS critical_count
            FROM LEARNING_DB.MART.MART_PROJECT_360
            WHERE STATUS = 'ACTIVE'
        """)
        row = df.iloc[0]
        return {
            "total_projects": int(row["TOTAL_PROJECTS"]),
            "total_outstanding": float(row["TOTAL_OUTSTANDING"]),
            "overdue_count": int(row["OVERDUE_COUNT"]),
            "critical_count": int(row["CRITICAL_COUNT"]),
        }
    except Exception:
        return {
            "total_projects": 0,
            "total_outstanding": 0.0,
            "overdue_count": 0,
            "critical_count": 0,
        }

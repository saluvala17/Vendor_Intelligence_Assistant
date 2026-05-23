"""
AI-powered vendor analytics using Claude API with SQL tool use.

Flow:
  1. User question → Claude generates SQL via tool call
  2. SQL executes against Snowflake MART tables
  3. Results → Claude produces executive summary
"""

import os
import json
import anthropic
import pandas as pd
from typing import Generator
from utils.snowflake_conn import get_snowflake_connection

SYSTEM_PROMPT = """You are a senior financial analyst for a Fortune 500 real estate company.
You have direct access to vendor intelligence data via the execute_sql tool.

Your database has two primary tables in the LEARNING_DB.MART schema:
- MART_VENDOR_360: 360-degree vendor view with risk scores, contract status, outstanding balances
- MART_VENDOR_PAYMENTS: Invoice-level payment data with priority scoring

Key columns in MART_VENDOR_360:
  VENDOR_ID, VENDOR_NAME, VENDOR_TYPE, COUNTRY, PAYMENT_TERMS,
  RISK_RATING (LOW/MEDIUM/HIGH), ACCOUNT_MANAGER, STATUS (ACTIVE/INACTIVE),
  ANNUAL_SPEND, CREDIT_LIMIT, CREDIT_UTILIZATION_PCT,
  CONTRACT_END, CONTRACT_DAYS_REMAINING, IS_EXPIRING_SOON,
  TOTAL_INVOICE_AMOUNT, TOTAL_PAID_AMOUNT, TOTAL_OUTSTANDING_AMOUNT,
  INVOICE_COUNT, OVERDUE_INVOICE_COUNT, PENDING_INVOICE_COUNT,
  AVG_DAYS_OVERDUE, HAS_OVERDUE_INVOICES,
  RISK_SCORE (1-6), RISK_SCORE_CATEGORY (CRITICAL/WATCH/STABLE)

Key columns in MART_VENDOR_PAYMENTS:
  INVOICE_ID, VENDOR_ID, INVOICE_DATE, DUE_DATE,
  INVOICE_AMOUNT, PAID_AMOUNT, OUTSTANDING_AMOUNT, STATUS,
  BUSINESS_UNIT (BU_WEST/BU_EAST/BU_CENTRAL), CATEGORY, COST_CENTER,
  APPROVER, PAYMENT_METHOD, DAYS_OVERDUE, PAYMENT_PRIORITY (HIGH/MEDIUM/LOW),
  APPROVER_ACTION_REQUIRED, PAYMENT_BREACH

RESPONSE RULES:
- Always call execute_sql first to get real data before answering.
- Lead with the most critical risk finding.
- Use exact vendor names and dollar amounts from the query results.
- Flag CRITICAL risk vendors with 🔴 emoji.
- Flag HIGH risk vendors with ⚠️ emoji.
- Format dollar amounts as $X,XXX,XXX (with commas).
- End every response with: RECOMMENDED ACTION: [specific next step with owner name]
- Keep the executive summary under 200 words.
- Use Snowflake SQL syntax (no LIMIT without ORDER BY).
"""

TOOLS = [
    {
        "name": "execute_sql",
        "description": (
            "Executes a SQL query against the Snowflake LEARNING_DB data warehouse "
            "and returns the results as JSON. Always use fully qualified table names "
            "like LEARNING_DB.MART.MART_VENDOR_360. Use Snowflake SQL syntax."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "sql": {
                    "type": "string",
                    "description": "The SQL query to execute. Must be valid Snowflake SQL.",
                }
            },
            "required": ["sql"],
        },
    }
]


def _run_tool(tool_name: str, tool_input: dict) -> tuple[str, pd.DataFrame]:
    """Executes a tool call and returns (json_result, dataframe)."""
    if tool_name != "execute_sql":
        return json.dumps({"error": f"Unknown tool: {tool_name}"}), pd.DataFrame()

    sql = tool_input.get("sql", "").strip()
    if not sql:
        return json.dumps({"error": "Empty SQL query"}), pd.DataFrame()

    try:
        conn = get_snowflake_connection()
        df = conn.execute_query(sql)
        result_json = df.to_json(orient="records", date_format="iso")
        return result_json, df
    except Exception as e:
        error_msg = str(e)
        return json.dumps({"error": error_msg}), pd.DataFrame()


def ask_vendor_analyst(
    question: str,
) -> Generator[dict, None, None]:
    """
    Sends a question to Claude with SQL tool access.

    Yields dicts with keys:
      {"type": "sql",      "content": sql_string}
      {"type": "data",     "content": dataframe}
      {"type": "text",     "content": text_chunk}
      {"type": "error",    "content": error_message}
    """
    client = anthropic.Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))

    messages = [{"role": "user", "content": question}]
    last_df = pd.DataFrame()
    last_sql = ""

    while True:
        response = client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=2048,
            system=SYSTEM_PROMPT,
            tools=TOOLS,
            messages=messages,
        )

        tool_calls_made = False

        for block in response.content:
            if block.type == "tool_use":
                tool_calls_made = True
                last_sql = block.input.get("sql", "")
                yield {"type": "sql", "content": last_sql}

                result_json, df = _run_tool(block.name, block.input)
                last_df = df

                if not df.empty:
                    yield {"type": "data", "content": df}

                messages.append({"role": "assistant", "content": response.content})
                messages.append({
                    "role": "user",
                    "content": [
                        {
                            "type": "tool_result",
                            "tool_use_id": block.id,
                            "content": result_json,
                        }
                    ],
                })

        if response.stop_reason == "end_turn" or not tool_calls_made:
            for block in response.content:
                if hasattr(block, "text") and block.text:
                    yield {"type": "text", "content": block.text}
            break

        if response.stop_reason == "tool_use":
            continue

        break

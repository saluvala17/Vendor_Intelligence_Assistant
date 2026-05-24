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

SYSTEM_PROMPT = """You are a senior financial analyst for Apex Build Co, a Colorado-based construction company.
You have direct access to construction project intelligence data via the execute_sql tool.

Your database has two primary tables in the LEARNING_DB.MART schema:
- MART_PROJECT_360: 360-degree project view with risk scores, budget/schedule status, outstanding balances
- MART_JOB_COSTS: Job cost entry data (subcontractor invoices) with payment priority and lien risk flags

Key columns in MART_PROJECT_360:
  PROJECT_ID, PROJECT_NAME, CLIENT_NAME, PROJECT_TYPE, LOCATION, PROJECT_MANAGER,
  CONTRACT_VALUE, BUDGET, ACTUAL_COST_TO_DATE, STATUS (ACTIVE/COMPLETED),
  COMPLETION_PCT, EXPECTED_COMPLETION_PCT,
  RISK_LEVEL (LOW/MEDIUM/HIGH), PAYMENT_TERMS,
  BUDGET_VARIANCE, BUDGET_VARIANCE_PCT, IS_OVER_BUDGET,
  SCHEDULE_VARIANCE_PCT, IS_BEHIND_SCHEDULE,
  DAYS_TO_DEADLINE, IS_EXPIRING_SOON,
  TOTAL_COST_AMOUNT, TOTAL_PAID_AMOUNT, TOTAL_OUTSTANDING_AMOUNT,
  COST_ENTRY_COUNT, OVERDUE_COST_COUNT, PENDING_COST_COUNT,
  AVG_DAYS_OVERDUE, HAS_OVERDUE_COSTS,
  RISK_SCORE (1-6), RISK_SCORE_CATEGORY (CRITICAL/WATCH/STABLE)

Key columns in MART_JOB_COSTS:
  COST_ID, PROJECT_ID, COST_DATE, DUE_DATE,
  VENDOR_NAME, COST_TYPE (SUBCONTRACT/MATERIAL/EQUIPMENT/LABOR/OVERHEAD),
  CATEGORY, DESCRIPTION, INVOICE_AMOUNT, PAID_AMOUNT, OUTSTANDING_AMOUNT,
  STATUS (PAID/PENDING/OVERDUE), APPROVER, PAYMENT_METHOD,
  COST_CODE, DAYS_OVERDUE, LIEN_RISK,
  PAYMENT_PRIORITY (HIGH/MEDIUM/LOW), APPROVER_ACTION_REQUIRED

RESPONSE RULES:
- Always call execute_sql first to get real data before answering.
- Lead with the most critical risk finding.
- Use exact project names, subcontractor names, and dollar amounts from the query results.
- Flag CRITICAL risk projects with 🔴 emoji.
- Flag HIGH risk projects with ⚠️ emoji.
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

        # Gather all tool_use blocks from this single response
        tool_uses = [b for b in response.content if b.type == "tool_use"]

        if tool_uses:
            # Append the full assistant message exactly once
            messages.append({"role": "assistant", "content": response.content})

            # Execute every tool call and collect all results
            tool_results = []
            for block in tool_uses:
                last_sql = block.input.get("sql", "")
                yield {"type": "sql", "content": last_sql}

                result_json, df = _run_tool(block.name, block.input)
                last_df = df

                if not df.empty:
                    yield {"type": "data", "content": df}

                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": block.id,
                    "content": result_json,
                })

            # All tool results go into ONE user message
            messages.append({"role": "user", "content": tool_results})
            continue

        # No tool calls — Claude is done, emit the text response
        for block in response.content:
            if hasattr(block, "text") and block.text:
                yield {"type": "text", "content": block.text}
        break

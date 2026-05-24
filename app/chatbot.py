"""
Vendor Intelligence Assistant — AI-powered chatbot for vendor analytics.
Powered by Snowflake + dbt + Claude API.

Run: streamlit run app/chatbot.py
"""

import os
import sys
import streamlit as st
import pandas as pd
from dotenv import load_dotenv

# Load .env before any imports that need credentials
load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

# Add app directory to path so utils imports work
sys.path.insert(0, os.path.dirname(__file__))

from utils.snowflake_conn import get_live_stats
from utils.cortex_analyst import ask_vendor_analyst

# ── Page configuration ────────────────────────────────────────────────────────
APP_TITLE = os.getenv("APP_TITLE", "Project Intelligence Assistant")
COMPANY_NAME = os.getenv("COMPANY_NAME", "Apex Build Co")
GITHUB_URL = os.getenv("GITHUB_REPO_URL", "https://github.com/saluvala17/vendor-dbt-demo")

st.set_page_config(
    page_title=APP_TITLE,
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ── Custom CSS ────────────────────────────────────────────────────────────────
st.markdown("""
<style>
    .main-header {
        font-size: 2rem;
        font-weight: 700;
        margin-bottom: 0.25rem;
    }
    .badge {
        display: inline-block;
        padding: 2px 10px;
        border-radius: 12px;
        font-size: 0.75rem;
        font-weight: 600;
        margin-right: 4px;
        background-color: #1a73e8;
        color: white;
    }
    .kpi-value {
        font-size: 1.6rem;
        font-weight: 700;
        color: #1a73e8;
    }
    .kpi-label {
        font-size: 0.75rem;
        color: #6c757d;
        text-transform: uppercase;
        letter-spacing: 0.05em;
    }
    .kpi-danger { color: #dc3545; }
    .sample-q {
        font-size: 0.82rem;
        text-align: left;
    }
    .footer {
        text-align: center;
        font-size: 0.75rem;
        color: #6c757d;
        padding: 1rem 0;
        border-top: 1px solid #dee2e6;
        margin-top: 2rem;
    }
    .stChatMessage { border-radius: 8px; }
</style>
""", unsafe_allow_html=True)

# ── Sample questions ───────────────────────────────────────────────────────────
SAMPLE_QUESTIONS = [
    "Which projects are over budget?",
    "What is our total outstanding job cost balance?",
    "Which projects are behind schedule?",
    "Who has the most pending payment approvals?",
    "Show electrical category spend across all projects",
    "Which HIGH risk projects have overdue subcontractor payments?",
]

# ── Session state initialization ──────────────────────────────────────────────
if "messages" not in st.session_state:
    st.session_state.messages = []
if "pending_question" not in st.session_state:
    st.session_state.pending_question = None

# ── Sidebar ───────────────────────────────────────────────────────────────────
with st.sidebar:
    st.markdown(f"### 📊 {COMPANY_NAME}")
    st.markdown("**Vendor Intelligence**")
    st.divider()

    # Live KPI stats
    st.markdown("**Live Stats** *(refreshes every 5 min)*")
    try:
        stats = get_live_stats()

        col1, col2 = st.columns(2)
        with col1:
            st.markdown(f'<div class="kpi-value">{stats["total_projects"]}</div>', unsafe_allow_html=True)
            st.markdown('<div class="kpi-label">Active Projects</div>', unsafe_allow_html=True)
        with col2:
            st.markdown(f'<div class="kpi-value kpi-danger">{stats["overdue_count"]}</div>', unsafe_allow_html=True)
            st.markdown('<div class="kpi-label">Overdue Costs</div>', unsafe_allow_html=True)

        st.markdown(f'<div class="kpi-value">${stats["total_outstanding"]:,.0f}</div>', unsafe_allow_html=True)
        st.markdown('<div class="kpi-label">Total Outstanding Costs</div>', unsafe_allow_html=True)

        st.markdown(f'<div class="kpi-value kpi-danger">{stats["critical_count"]}</div>', unsafe_allow_html=True)
        st.markdown('<div class="kpi-label">🔴 Critical Projects</div>', unsafe_allow_html=True)

    except Exception as e:
        st.warning(f"Stats unavailable: check Snowflake credentials in .env")

    st.divider()

    # Sample question buttons
    st.markdown("**Try a sample question:**")
    for q in SAMPLE_QUESTIONS:
        if st.button(q, key=f"sample_{q[:20]}", use_container_width=True,
                     help="Click to ask this question"):
            st.session_state.pending_question = q
            st.rerun()

    st.divider()

    # Architecture explainer
    with st.expander("⚙️ How it works"):
        st.markdown("""
**Config-Driven Architecture:**

1. `config/model_config.yml` — single source of truth for all column definitions
2. `load_config_to_snowflake.py` — loads config to Snowflake metadata table
3. **dbt** compiles staging views and mart tables from config
4. **Claude API** uses tool-use to generate SQL and interpret results
5. Results surface here as executive-ready insights

**Data Pipeline:**
```
YAML Config
    ↓
Snowflake RAW
    ↓ (dbt)
STAGING views
    ↓ (dbt)
MART tables
    ↓ (Claude)
This chatbot
```

**Models used:**
- `MART_PROJECT_360` — primary chatbot source
- `MART_JOB_COSTS` — cost & payment analysis
""")

# ── Main content ──────────────────────────────────────────────────────────────
st.markdown(f'<div class="main-header">📊 {APP_TITLE}</div>', unsafe_allow_html=True)
st.markdown(
    '<span class="badge">Snowflake</span>'
    '<span class="badge">dbt</span>'
    '<span class="badge">Claude AI</span>'
    '<span class="badge">Streamlit</span>',
    unsafe_allow_html=True,
)
st.markdown("")

# Welcome message (shown only on first load)
if not st.session_state.messages:
    st.info(
        "👋 **Welcome to Project Intelligence Assistant**\n\n"
        "I analyze Apex Build Co's construction project data in real time using AI. Ask me anything about:\n"
        "- Budget overruns and cost variance by project\n"
        "- Schedule delays and liquidated damages risk\n"
        "- Subcontractor payment backlogs and lien risk\n"
        "- Approver action queues and payment prioritization\n\n"
        "Type a question below or click a sample in the sidebar.",
        icon="📊",
    )

# Display chat history
for msg in st.session_state.messages:
    with st.chat_message(msg["role"]):
        st.markdown(msg["content"])
        if "sql" in msg and msg["sql"]:
            with st.expander("🔍 View SQL", expanded=False):
                st.code(msg["sql"], language="sql")
        if "dataframe" in msg and msg["dataframe"] is not None:
            with st.expander("📋 View Raw Data", expanded=False):
                st.dataframe(msg["dataframe"], use_container_width=True)

# ── Chat input ────────────────────────────────────────────────────────────────
question = st.chat_input("Ask about project budgets, schedules, subcontractor payments...")

# Handle sidebar button clicks
if st.session_state.pending_question:
    question = st.session_state.pending_question
    st.session_state.pending_question = None

if question:
    # Display user message
    st.session_state.messages.append({"role": "user", "content": question})
    with st.chat_message("user"):
        st.markdown(question)

    # Stream Claude response
    with st.chat_message("assistant"):
        sql_captured = ""
        df_captured = None
        full_response = ""

        with st.spinner("Analyzing vendor data..."):
            response_placeholder = st.empty()
            sql_placeholder = st.empty()
            data_placeholder = st.empty()

            try:
                for chunk in ask_vendor_analyst(question):
                    if chunk["type"] == "sql":
                        sql_captured = chunk["content"]

                    elif chunk["type"] == "data":
                        df_captured = chunk["content"]

                    elif chunk["type"] == "text":
                        full_response += chunk["content"]
                        response_placeholder.markdown(full_response)

                    elif chunk["type"] == "error":
                        st.error(f"Query error: {chunk['content']}")

            except Exception as e:
                err = str(e)
                if "ANTHROPIC_API_KEY" in err or "api_key" in err.lower():
                    full_response = "❌ Missing ANTHROPIC_API_KEY. Add it to your .env file."
                elif "snowflake" in err.lower() or "250001" in err:
                    full_response = "❌ Snowflake connection failed. Check SNOWFLAKE_* variables in .env."
                else:
                    full_response = f"❌ Unexpected error: {err}"
                response_placeholder.markdown(full_response)

        # Show expandable SQL and data after streaming completes
        if sql_captured:
            with st.expander("🔍 View SQL", expanded=False):
                st.code(sql_captured, language="sql")

        if df_captured is not None and not df_captured.empty:
            with st.expander("📋 View Raw Data", expanded=False):
                st.dataframe(df_captured, use_container_width=True)

    # Save assistant message to history
    st.session_state.messages.append({
        "role": "assistant",
        "content": full_response,
        "sql": sql_captured,
        "dataframe": df_captured,
    })

# ── Footer ────────────────────────────────────────────────────────────────────
st.markdown(
    f'<div class="footer">'
    f'Built with Snowflake + dbt + Claude | '
    f'<a href="{GITHUB_URL}" target="_blank">View on GitHub</a> | '
    f'<a href="http://localhost:8080" target="_blank">dbt Lineage Docs</a>'
    f'</div>',
    unsafe_allow_html=True,
)

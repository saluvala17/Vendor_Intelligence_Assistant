"""
ConstructIQ — AI-powered project intelligence for Apex Build Co.
Run: streamlit run app/chatbot.py
"""

import os
import sys
import streamlit as st
import pandas as pd
import plotly.graph_objects as go
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))
sys.path.insert(0, os.path.dirname(__file__))

from utils.cortex_analyst import ask_vendor_analyst

# ── Page config ───────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="ConstructIQ",
    page_icon="🏗️",
    layout="wide",
    initial_sidebar_state="collapsed",
)

# ── CSS: Claude-inspired light theme ─────────────────────────────────────────
st.markdown("""
<style>
  /* ── Global ── */
  [data-testid="stAppViewContainer"] {
      background: #F7F8FA;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  }
  [data-testid="stHeader"] { background: transparent; }
  [data-testid="stSidebar"] { display: none; }
  footer { visibility: hidden; }

  /* ── Header bar ── */
  .ciq-header {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 14px 0 10px 0;
      border-bottom: 1px solid #E5E7EB;
      margin-bottom: 20px;
  }
  .ciq-logo {
      width: 40px; height: 40px; border-radius: 8px;
      background: #E8720C;
      display: flex; align-items: center; justify-content: center;
      font-size: 20px; flex-shrink: 0;
  }
  .ciq-brand { line-height: 1.15; }
  .ciq-name {
      font-size: 1.15rem; font-weight: 700; color: #111827; letter-spacing: -0.01em;
  }
  .ciq-sub { font-size: 0.7rem; color: #9CA3AF; }
  .ciq-company {
      margin-left: auto; font-size: 0.78rem; color: #6B7280;
      border: 1px solid #E5E7EB; border-radius: 20px;
      padding: 4px 12px; background: white;
  }

  /* ── KPI cards ── */
  .kpi-wrap {
      background: white; border-radius: 10px;
      border: 1px solid #E5E7EB;
      padding: 14px 16px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.05);
  }
  .kpi-val {
      font-size: 1.6rem; font-weight: 700; color: #111827; line-height: 1.1;
  }
  .kpi-val-red  { font-size: 1.6rem; font-weight: 700; color: #DC2626; line-height: 1.1; }
  .kpi-val-ora  { font-size: 1.6rem; font-weight: 700; color: #E8720C; line-height: 1.1; }
  .kpi-lbl {
      font-size: 0.68rem; color: #9CA3AF; text-transform: uppercase;
      letter-spacing: 0.06em; margin-top: 4px;
  }
  .kpi-badge-red {
      display:inline-block; background:#FEF2F2; color:#DC2626;
      border-radius:4px; padding:1px 6px; font-size:0.65rem; font-weight:600;
      margin-top:4px;
  }
  .kpi-badge-ora {
      display:inline-block; background:#FFF7ED; color:#E8720C;
      border-radius:4px; padding:1px 6px; font-size:0.65rem; font-weight:600;
      margin-top:4px;
  }

  /* ── Section titles ── */
  .section-title {
      font-size: 0.78rem; font-weight: 600; color: #374151;
      text-transform: uppercase; letter-spacing: 0.06em;
      margin-bottom: 10px; margin-top: 4px;
  }

  /* ── Chart card ── */
  .chart-card {
      background: white; border-radius: 10px;
      border: 1px solid #E5E7EB;
      padding: 16px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.05);
  }

  /* ── Divider ── */
  .ciq-divider {
      border: none; border-top: 1px solid #E5E7EB;
      margin: 20px 0 16px 0;
  }

  /* ── AI Section label ── */
  .ai-section-header {
      font-size: 0.85rem; font-weight: 600; color: #374151;
      margin-bottom: 12px;
      display: flex; align-items: center; gap: 8px;
  }
  .ai-dot {
      width: 8px; height: 8px; border-radius: 50%; background: #E8720C;
      display: inline-block;
  }

  /* ── Sample questions ── */
  .sq-label {
      font-size: 0.68rem; color: #9CA3AF; margin-bottom: 6px;
      text-transform: uppercase; letter-spacing: 0.05em;
  }
  [data-testid="stButton"] > button {
      font-size: 0.72rem !important;
      padding: 4px 10px !important;
      border-radius: 16px !important;
      background: white !important;
      border: 1px solid #E5E7EB !important;
      color: #374151 !important;
      font-weight: 400 !important;
      box-shadow: none !important;
      height: auto !important;
      line-height: 1.4 !important;
  }
  [data-testid="stButton"] > button:hover {
      border-color: #E8720C !important;
      color: #E8720C !important;
      background: #FFF7ED !important;
  }

  /* ── Chat ── */
  [data-testid="stChatMessage"] {
      border-radius: 10px;
      font-size: 0.85rem;
  }
  [data-testid="stChatInputTextArea"] {
      font-size: 0.85rem !important;
  }
</style>
""", unsafe_allow_html=True)

# ── Static dashboard data (Apex Build Co sample dataset) ─────────────────────
# KPIs computed from 15 projects / 50 job cost entries
STATIC_KPI = {
    "total_projects":    14,        # 14 ACTIVE (P014 completed)
    "critical_count":    3,         # P001 score=6, P002 score=5, P013 score=5
    "over_budget_count": 1,         # P001: $920k actual vs $850k budget
    "total_outstanding": 1_439_000, # PENDING $1.05M + OVERDUE $387k
    "pending_approvals": 18,        # 18 PENDING cost entries across all PMs
}

# Top 8 projects by budget — for Budget vs Actual chart
STATIC_BUDGET = pd.DataFrame({
    "PROJECT_NAME": [
        "Regional Water Treatment",
        "Southgate Shopping Expan.",
        "Riverside Apartments Ph.2",
        "Industrial Warehouse",
        "Alpine Luxury Homes",
        "Highway Bridge Repair",
        "Westfield Parking Struct.",
        "Downtown Office Renov.",
    ],
    "BUDGET_K": [3200, 2500, 2100, 1800, 1400, 1200, 890, 850],
    "ACTUAL_K": [1280, 1500, 1260,  900,  700,  575, 312, 920],
    "IS_OVER_BUDGET": [False, False, False, False, False, False, False, True],
})

# Risk distribution — for donut chart
STATIC_RISK = pd.DataFrame({
    "RISK_SCORE_CATEGORY": ["CRITICAL", "WATCH", "STABLE"],
    "CNT": [3, 4, 7],
})

# Pending approvals by PM — for bar chart
STATIC_PM = pd.DataFrame({
    "PROJECT_MANAGER": ["Mike Davis", "Sarah Johnson", "James Wilson", "Emily Chen", "Robert Brown"],
    "PENDING_COUNT":   [7, 3, 3, 3, 2],
    "PENDING_AMOUNT":  [340_000, 262_000, 245_000, 115_000, 90_000],
})

# ── Constants ─────────────────────────────────────────────────────────────────
LOGO_SVG = """
<svg width="24" height="24" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <rect x="2" y="14" width="5" height="9" fill="white" opacity="0.95"/>
  <rect x="9" y="10" width="5" height="13" fill="white" opacity="0.95"/>
  <rect x="16" y="6" width="6" height="17" fill="white" opacity="0.95"/>
  <rect x="1" y="22" width="22" height="1.5" fill="white"/>
</svg>"""

SAMPLE_QUESTIONS = [
    "Which projects are over budget?",
    "What's our total outstanding balance?",
    "Who has the most pending approvals?",
    "Projects behind schedule?",
    "Show lien risk subcontractors",
    "Electrical spend across all projects",
]

# ── Session state ─────────────────────────────────────────────────────────────
if "messages" not in st.session_state:
    st.session_state.messages = []
if "pending_q" not in st.session_state:
    st.session_state.pending_q = None

# ── Header ────────────────────────────────────────────────────────────────────
st.markdown(f"""
<div class="ciq-header">
  <div class="ciq-logo">{LOGO_SVG}</div>
  <div class="ciq-brand">
    <div class="ciq-name">ConstructIQ</div>
    <div class="ciq-sub">Project Intelligence Platform</div>
  </div>
  <div class="ciq-company">Apex Build Co &nbsp;·&nbsp; Colorado</div>
</div>
""", unsafe_allow_html=True)

# ── Dashboard — use static sample data ───────────────────────────────────────
total_projects    = STATIC_KPI["total_projects"]
critical_count    = STATIC_KPI["critical_count"]
over_budget_count = STATIC_KPI["over_budget_count"]
total_outstanding = STATIC_KPI["total_outstanding"]
pending_approvals = STATIC_KPI["pending_approvals"]
budget_df = STATIC_BUDGET
risk_df   = STATIC_RISK
pm_df     = STATIC_PM

# KPI row
st.markdown('<div class="section-title">Project Overview</div>', unsafe_allow_html=True)

k1, k2, k3, k4, k5 = st.columns(5)

with k1:
    st.markdown(f"""
    <div class="kpi-wrap">
      <div class="kpi-val">{total_projects}</div>
      <div class="kpi-lbl">Active Projects</div>
    </div>""", unsafe_allow_html=True)

with k2:
    st.markdown(f"""
    <div class="kpi-wrap">
      <div class="kpi-val-red">{critical_count}</div>
      <div class="kpi-lbl">Critical Risk</div>
      <div class="kpi-badge-red">Needs attention</div>
    </div>""", unsafe_allow_html=True)

with k3:
    st.markdown(f"""
    <div class="kpi-wrap">
      <div class="kpi-val-ora">{over_budget_count}</div>
      <div class="kpi-lbl">Over Budget</div>
      <div class="kpi-badge-ora">Budget breach</div>
    </div>""", unsafe_allow_html=True)

with k4:
    outstanding_fmt = f"${total_outstanding/1_000_000:.1f}M" if total_outstanding >= 1_000_000 else f"${total_outstanding:,.0f}"
    st.markdown(f"""
    <div class="kpi-wrap">
      <div class="kpi-val">{outstanding_fmt}</div>
      <div class="kpi-lbl">Outstanding Costs</div>
    </div>""", unsafe_allow_html=True)

with k5:
    st.markdown(f"""
    <div class="kpi-wrap">
      <div class="kpi-val-ora">{pending_approvals}</div>
      <div class="kpi-lbl">Pending Approvals</div>
    </div>""", unsafe_allow_html=True)

st.markdown("<div style='height:14px'></div>", unsafe_allow_html=True)

# Chart row
ch1, ch2, ch3 = st.columns([5, 3, 4])

# Chart 1 — Budget vs Actual
with ch1:
    st.markdown('<div class="chart-card">', unsafe_allow_html=True)
    st.markdown('<div class="section-title">Budget vs Actual Cost ($K)</div>', unsafe_allow_html=True)
    short_names = budget_df["PROJECT_NAME"].tolist()
    bar_colors  = ["#DC2626" if v else "#E8720C" for v in budget_df["IS_OVER_BUDGET"].tolist()]
    fig = go.Figure()
    fig.add_trace(go.Bar(
        name="Budget",
        y=short_names, x=budget_df["BUDGET_K"],
        orientation="h", marker_color="#E5E7EB", marker_line_width=0,
    ))
    fig.add_trace(go.Bar(
        name="Actual",
        y=short_names, x=budget_df["ACTUAL_K"],
        orientation="h", marker_color=bar_colors, marker_line_width=0,
    ))
    fig.update_layout(
        barmode="overlay", height=240,
        margin=dict(l=0, r=10, t=4, b=0),
        paper_bgcolor="white", plot_bgcolor="white",
        font=dict(size=10, color="#374151"),
        legend=dict(orientation="h", yanchor="bottom", y=1.0, xanchor="right", x=1,
                    font=dict(size=9)),
        xaxis=dict(showgrid=True, gridcolor="#F3F4F6", zeroline=False,
                   tickfont=dict(size=9), tickprefix="$", ticksuffix="K"),
        yaxis=dict(tickfont=dict(size=9)),
    )
    st.plotly_chart(fig, use_container_width=True, config={"displayModeBar": False})
    st.markdown('</div>', unsafe_allow_html=True)

# Chart 2 — Risk donut
with ch2:
    st.markdown('<div class="chart-card">', unsafe_allow_html=True)
    st.markdown('<div class="section-title">Risk Breakdown</div>', unsafe_allow_html=True)
    color_map = {"CRITICAL": "#DC2626", "WATCH": "#E8720C", "STABLE": "#16A34A"}
    colors = [color_map.get(c, "#9CA3AF") for c in risk_df["RISK_SCORE_CATEGORY"].tolist()]
    fig2 = go.Figure(go.Pie(
        labels=risk_df["RISK_SCORE_CATEGORY"],
        values=risk_df["CNT"],
        hole=0.6,
        marker_colors=colors,
        textfont_size=10,
        showlegend=True,
    ))
    fig2.update_layout(
        height=240,
        margin=dict(l=0, r=0, t=4, b=0),
        paper_bgcolor="white",
        font=dict(size=10, color="#374151"),
        legend=dict(orientation="h", yanchor="bottom", y=-0.15, font=dict(size=9)),
    )
    st.plotly_chart(fig2, use_container_width=True, config={"displayModeBar": False})
    st.markdown('</div>', unsafe_allow_html=True)

# Chart 3 — Pending approvals by PM
with ch3:
    st.markdown('<div class="chart-card">', unsafe_allow_html=True)
    st.markdown('<div class="section-title">Pending Approvals by Project Manager ($)</div>', unsafe_allow_html=True)
    first_names = [n.split()[0] for n in pm_df["PROJECT_MANAGER"].tolist()]
    fig3 = go.Figure(go.Bar(
        x=first_names,
        y=pm_df["PENDING_AMOUNT"],
        marker_color="#E8720C",
        marker_line_width=0,
        text=[f"${v/1000:.0f}K" for v in pm_df["PENDING_AMOUNT"]],
        textposition="outside",
        textfont=dict(size=9),
    ))
    fig3.update_layout(
        height=240,
        margin=dict(l=0, r=10, t=20, b=0),
        paper_bgcolor="white",
        plot_bgcolor="white",
        font=dict(size=10, color="#374151"),
        xaxis=dict(tickfont=dict(size=9)),
        yaxis=dict(showgrid=True, gridcolor="#F3F4F6", zeroline=False,
                   tickfont=dict(size=9), tickprefix="$"),
    )
    st.plotly_chart(fig3, use_container_width=True, config={"displayModeBar": False})
    st.markdown('</div>', unsafe_allow_html=True)

# ── AI Chat Section ───────────────────────────────────────────────────────────
st.markdown('<hr class="ciq-divider">', unsafe_allow_html=True)
st.markdown("""
<div class="ai-section-header">
  <span class="ai-dot"></span> Ask ConstructIQ
</div>""", unsafe_allow_html=True)

# Chat history
for msg in st.session_state.messages:
    with st.chat_message(msg["role"]):
        st.markdown(msg["content"])
        if msg.get("sql"):
            with st.expander("View query", expanded=False):
                st.code(msg["sql"], language="sql")
        if msg.get("dataframe") is not None and not msg["dataframe"].empty:
            with st.expander("View data", expanded=False):
                st.dataframe(msg["dataframe"], use_container_width=True)

# Chat input
question = st.chat_input("Ask about budgets, schedules, approvals, subcontractor payments…")

# Handle sidebar-style button click
if st.session_state.pending_q:
    question = st.session_state.pending_q
    st.session_state.pending_q = None

# ── Sample questions (below input) ────────────────────────────────────────────
st.markdown('<div class="sq-label">Suggested questions</div>', unsafe_allow_html=True)
sq_cols = st.columns(len(SAMPLE_QUESTIONS))
for i, q in enumerate(SAMPLE_QUESTIONS):
    if sq_cols[i].button(q, key=f"sq_{i}"):
        st.session_state.pending_q = q
        st.rerun()

# ── Handle question ───────────────────────────────────────────────────────────
if question:
    st.session_state.messages.append({"role": "user", "content": question})
    with st.chat_message("user"):
        st.markdown(question)

    with st.chat_message("assistant"):
        sql_captured = ""
        df_captured = None
        full_response = ""

        with st.spinner("Analyzing…"):
            response_placeholder = st.empty()
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
                    full_response = "Missing API key — add ANTHROPIC_API_KEY to your .env file."
                elif "snowflake" in err.lower() or "250001" in err:
                    full_response = "Connection failed — check SNOWFLAKE_* variables in your .env file."
                else:
                    full_response = f"Error: {err}"
                response_placeholder.markdown(full_response)

        if sql_captured:
            with st.expander("View query", expanded=False):
                st.code(sql_captured, language="sql")
        if df_captured is not None and not df_captured.empty:
            with st.expander("View data", expanded=False):
                st.dataframe(df_captured, use_container_width=True)

    st.session_state.messages.append({
        "role": "assistant",
        "content": full_response,
        "sql": sql_captured,
        "dataframe": df_captured,
    })

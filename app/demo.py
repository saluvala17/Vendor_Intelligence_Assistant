"""
ConstructIQ Demo — AI-powered project intelligence, no database required.
Loads data from data/projects.csv and data/job_costs.csv.
Uses Claude API directly with pandas DataFrames as context.

Run: streamlit run app/demo.py
"""

import os
import anthropic
import pandas as pd
import plotly.graph_objects as go
import streamlit as st
from pathlib import Path
from dotenv import load_dotenv

load_dotenv(Path(__file__).parent.parent / ".env")

# ── Page config ───────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="ConstructIQ Demo",
    page_icon="🏗️",
    layout="wide",
    initial_sidebar_state="collapsed",
)

# ── CSS: identical to chatbot.py ──────────────────────────────────────────────
st.markdown("""
<style>
  [data-testid="stAppViewContainer"] {
      background: #F7F8FA;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  }
  [data-testid="stHeader"] { background: transparent; }
  [data-testid="stSidebar"] { display: none; }
  footer { visibility: hidden; }

  .ciq-header {
      display: flex; align-items: center; gap: 12px;
      padding: 14px 0 10px 0;
      border-bottom: 1px solid #E5E7EB; margin-bottom: 20px;
  }
  .ciq-logo {
      width: 40px; height: 40px; border-radius: 8px; background: #E8720C;
      display: flex; align-items: center; justify-content: center;
      font-size: 20px; flex-shrink: 0;
  }
  .ciq-brand { line-height: 1.15; }
  .ciq-name  { font-size: 1.15rem; font-weight: 700; color: #111827; letter-spacing: -0.01em; }
  .ciq-sub   { font-size: 0.7rem; color: #9CA3AF; }
  .ciq-company {
      margin-left: auto; font-size: 0.78rem; color: #6B7280;
      border: 1px solid #E5E7EB; border-radius: 20px; padding: 4px 12px; background: white;
  }
  .demo-badge {
      font-size: 0.65rem; font-weight: 600; color: #E8720C;
      background: #FFF7ED; border: 1px solid #FED7AA;
      border-radius: 20px; padding: 3px 10px; margin-left: 8px;
  }

  .kpi-wrap  {
      background: white; border-radius: 10px; border: 1px solid #E5E7EB;
      padding: 14px 16px; box-shadow: 0 1px 3px rgba(0,0,0,0.05);
  }
  .kpi-val      { font-size: 1.6rem; font-weight: 700; color: #111827; line-height: 1.1; }
  .kpi-val-red  { font-size: 1.6rem; font-weight: 700; color: #DC2626; line-height: 1.1; }
  .kpi-val-ora  { font-size: 1.6rem; font-weight: 700; color: #E8720C; line-height: 1.1; }
  .kpi-lbl      { font-size: 0.68rem; color: #9CA3AF; text-transform: uppercase; letter-spacing: 0.06em; margin-top: 4px; }
  .kpi-badge-red {
      display:inline-block; background:#FEF2F2; color:#DC2626;
      border-radius:4px; padding:1px 6px; font-size:0.65rem; font-weight:600; margin-top:4px;
  }
  .kpi-badge-ora {
      display:inline-block; background:#FFF7ED; color:#E8720C;
      border-radius:4px; padding:1px 6px; font-size:0.65rem; font-weight:600; margin-top:4px;
  }

  .section-title {
      font-size: 0.78rem; font-weight: 600; color: #374151;
      text-transform: uppercase; letter-spacing: 0.06em; margin-bottom: 10px; margin-top: 4px;
  }
  .chart-card {
      background: white; border-radius: 10px; border: 1px solid #E5E7EB;
      padding: 16px; box-shadow: 0 1px 3px rgba(0,0,0,0.05);
  }
  .ciq-divider { border: none; border-top: 1px solid #E5E7EB; margin: 20px 0 16px 0; }
  .ai-section-header {
      font-size: 0.85rem; font-weight: 600; color: #374151;
      margin-bottom: 12px; display: flex; align-items: center; gap: 8px;
  }
  .ai-dot { width: 8px; height: 8px; border-radius: 50%; background: #E8720C; display: inline-block; }

  .sq-label { font-size: 0.68rem; color: #9CA3AF; margin-bottom: 6px; text-transform: uppercase; letter-spacing: 0.05em; }

  .rate-limit-box {
      background: #FFF7ED; border: 1px solid #FED7AA; border-radius: 10px;
      padding: 16px 20px; text-align: center; margin: 12px 0;
  }
  .rate-limit-title { font-size: 0.95rem; font-weight: 700; color: #92400E; margin-bottom: 4px; }
  .rate-limit-sub   { font-size: 0.78rem; color: #B45309; }
  .rate-limit-code  { font-family: monospace; background: #FEF3C7; border-radius: 4px; padding: 2px 8px; font-size: 0.76rem; }

  [data-testid="stButton"] > button {
      font-size: 0.72rem !important; padding: 4px 10px !important;
      border-radius: 16px !important; background: white !important;
      border: 1px solid #E5E7EB !important; color: #374151 !important;
      font-weight: 400 !important; box-shadow: none !important;
      height: auto !important; line-height: 1.4 !important;
  }
  [data-testid="stButton"] > button:hover {
      border-color: #E8720C !important; color: #E8720C !important; background: #FFF7ED !important;
  }
  [data-testid="stChatMessage"]     { border-radius: 10px; font-size: 0.85rem; }
  [data-testid="stChatInputTextArea"] { font-size: 0.85rem !important; }
</style>
""", unsafe_allow_html=True)

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

MAX_QUESTIONS = 5

# ── Session state ─────────────────────────────────────────────────────────────
if "messages"       not in st.session_state: st.session_state.messages       = []
if "question_count" not in st.session_state: st.session_state.question_count = 0
if "pending_q"      not in st.session_state: st.session_state.pending_q      = None

# ── Data loading ──────────────────────────────────────────────────────────────
@st.cache_data
def load_data() -> tuple[pd.DataFrame, pd.DataFrame]:
    base = Path(__file__).parent.parent / "data"
    projects  = pd.read_csv(base / "projects.csv")
    job_costs = pd.read_csv(base / "job_costs.csv")

    # Derived columns — mirror the dbt staging logic
    projects["IS_OVER_BUDGET"]     = projects["ACTUAL_COST_TO_DATE"] > projects["BUDGET"]
    projects["IS_BEHIND_SCHEDULE"] = projects["COMPLETION_PCT"] < projects["EXPECTED_COMPLETION_PCT"]
    projects["BUDGET_VARIANCE"]    = projects["ACTUAL_COST_TO_DATE"] - projects["BUDGET"]
    projects["BUDGET_VARIANCE_PCT"] = ((projects["ACTUAL_COST_TO_DATE"] - projects["BUDGET"])
                                        / projects["BUDGET"] * 100).round(2)

    overdue_pids = set(job_costs[job_costs["STATUS"] == "OVERDUE"]["PROJECT_ID"])

    def _risk_score(row):
        base = {"HIGH": 3, "MEDIUM": 2, "LOW": 1}.get(row["RISK_LEVEL"], 1)
        return (base
                + (1 if row["IS_OVER_BUDGET"]     else 0)
                + (1 if row["IS_BEHIND_SCHEDULE"] else 0)
                + (1 if row["PROJECT_ID"] in overdue_pids else 0))

    projects["RISK_SCORE"]    = projects.apply(_risk_score, axis=1)
    projects["RISK_CATEGORY"] = projects["RISK_SCORE"].apply(
        lambda s: "CRITICAL" if s >= 5 else ("WATCH" if s >= 3 else "STABLE")
    )

    job_costs["OUTSTANDING"] = (
        job_costs["INVOICE_AMOUNT"] - job_costs["PAID_AMOUNT"].fillna(0)
    )

    return projects, job_costs


@st.cache_data
def compute_kpis(projects: pd.DataFrame, job_costs: pd.DataFrame) -> dict:
    active = projects[projects["STATUS"] == "ACTIVE"]
    non_paid = job_costs[job_costs["STATUS"].isin(["PENDING", "OVERDUE"])]
    return {
        "total_projects":    len(active),
        "critical_count":    int((active["RISK_CATEGORY"] == "CRITICAL").sum()),
        "over_budget_count": int(active["IS_OVER_BUDGET"].sum()),
        "total_outstanding": float(non_paid["OUTSTANDING"].sum()),
        "pending_approvals": int((job_costs["STATUS"] == "PENDING").sum()),
    }


@st.cache_data
def compute_charts(projects: pd.DataFrame, job_costs: pd.DataFrame):
    active = projects[projects["STATUS"] == "ACTIVE"]

    # Budget vs Actual — top 8 by budget
    top8 = (active.nlargest(8, "BUDGET")
            [["PROJECT_NAME", "BUDGET", "ACTUAL_COST_TO_DATE", "IS_OVER_BUDGET"]]
            .copy())
    top8["BUDGET_K"] = top8["BUDGET"] / 1000
    top8["ACTUAL_K"] = top8["ACTUAL_COST_TO_DATE"] / 1000
    top8["PROJECT_NAME"] = top8["PROJECT_NAME"].apply(
        lambda n: n[:24] + "…" if len(n) > 24 else n
    )

    # Risk donut
    risk_df = (active["RISK_CATEGORY"]
               .value_counts()
               .rename_axis("RISK_SCORE_CATEGORY")
               .reset_index(name="CNT"))

    # Pending approvals by PM
    pending = job_costs[job_costs["STATUS"] == "PENDING"]
    pm_df   = (pending.groupby("APPROVER")
               .agg(PENDING_COUNT=("COST_ID", "count"),
                    PENDING_AMOUNT=("INVOICE_AMOUNT", "sum"))
               .reset_index()
               .rename(columns={"APPROVER": "PROJECT_MANAGER"})
               .nlargest(5, "PENDING_AMOUNT"))

    return top8, risk_df, pm_df


# ── Pandas query hints (shown in expander instead of SQL) ────────────────────
def pandas_hint(question: str) -> str:
    q = question.lower()
    if "over budget" in q or ("budget" in q and "highest" in q):
        return (
            "# Projects where actual cost exceeds approved budget\n"
            "projects[projects['ACTUAL_COST_TO_DATE'] > projects['BUDGET']]\n"
            "  [['PROJECT_NAME','BUDGET','ACTUAL_COST_TO_DATE','BUDGET_VARIANCE_PCT']]"
        )
    elif "behind schedule" in q or "schedule" in q:
        return (
            "# Projects where actual completion lags the plan\n"
            "projects[projects['COMPLETION_PCT'] < projects['EXPECTED_COMPLETION_PCT']]\n"
            "  [['PROJECT_NAME','COMPLETION_PCT','EXPECTED_COMPLETION_PCT']]"
        )
    elif "pending" in q or "approval" in q:
        return (
            "# Pending payments grouped by approver\n"
            "job_costs[job_costs['STATUS'] == 'PENDING']\n"
            "  .groupby('APPROVER')['INVOICE_AMOUNT'].sum()\n"
            "  .sort_values(ascending=False).reset_index()"
        )
    elif "overdue" in q or "lien" in q:
        return (
            "# Overdue entries — unpaid subs can file liens\n"
            "job_costs[job_costs['STATUS'] == 'OVERDUE']\n"
            "  [['PROJECT_ID','VENDOR_NAME','INVOICE_AMOUNT','PAID_AMOUNT','OUTSTANDING']]"
        )
    elif "outstanding" in q or "balance" in q:
        return (
            "# Total outstanding = PENDING + OVERDUE entries\n"
            "non_paid = job_costs[job_costs['STATUS'].isin(['PENDING','OVERDUE'])]\n"
            "outstanding = (non_paid['INVOICE_AMOUNT'] - non_paid['PAID_AMOUNT'].fillna(0)).sum()"
        )
    elif "electrical" in q:
        return (
            "# Electrical category spend by project\n"
            "job_costs[job_costs['CATEGORY'] == 'Electrical']\n"
            "  .groupby('PROJECT_ID')['INVOICE_AMOUNT'].sum().reset_index()"
        )
    elif "risk" in q or "critical" in q:
        return (
            "# Projects by risk score\n"
            "projects[projects['STATUS'] == 'ACTIVE']\n"
            "  [['PROJECT_NAME','RISK_LEVEL','RISK_SCORE','RISK_CATEGORY']]\n"
            "  .sort_values('RISK_SCORE', ascending=False)"
        )
    else:
        return (
            "# Active projects overview\n"
            "projects[projects['STATUS'] == 'ACTIVE']\n"
            "  [['PROJECT_NAME','PROJECT_MANAGER','BUDGET','ACTUAL_COST_TO_DATE','RISK_LEVEL']]"
        )


# ── Claude Q&A (no tool-use — data passed as context) ────────────────────────
def _build_system_prompt(projects_df: pd.DataFrame, job_costs_df: pd.DataFrame) -> str:
    # Select columns relevant for analysis to keep context tight
    p_cols = ["PROJECT_ID", "PROJECT_NAME", "CLIENT_NAME", "PROJECT_TYPE",
              "PROJECT_MANAGER", "BUDGET", "ACTUAL_COST_TO_DATE",
              "COMPLETION_PCT", "EXPECTED_COMPLETION_PCT", "RISK_LEVEL",
              "STATUS", "IS_OVER_BUDGET", "IS_BEHIND_SCHEDULE",
              "BUDGET_VARIANCE_PCT", "RISK_CATEGORY"]
    j_cols = ["COST_ID", "PROJECT_ID", "VENDOR_NAME", "COST_TYPE", "CATEGORY",
              "INVOICE_AMOUNT", "PAID_AMOUNT", "OUTSTANDING",
              "STATUS", "APPROVER", "DUE_DATE", "COST_CODE"]

    projects_ctx  = projects_df[p_cols].to_csv(index=False)
    job_costs_ctx = job_costs_df[j_cols].to_csv(index=False)

    return f"""You are a senior financial analyst for Apex Build Co, a Colorado-based construction company.
You have direct access to the following live project data. Base ALL answers strictly on this data.

=== PROJECTS (15 rows) ===
{projects_ctx}

=== JOB COSTS (50 subcontractor cost entries) ===
{job_costs_ctx}

COLUMN GUIDE:
- BUDGET: approved internal budget in USD
- ACTUAL_COST_TO_DATE: total spent so far in USD
- COMPLETION_PCT: actual % of work complete
- EXPECTED_COMPLETION_PCT: planned % based on schedule
- IS_OVER_BUDGET: True when ACTUAL_COST_TO_DATE > BUDGET
- IS_BEHIND_SCHEDULE: True when COMPLETION_PCT < EXPECTED_COMPLETION_PCT
- BUDGET_VARIANCE_PCT: % by which actual exceeds budget (positive = over)
- RISK_CATEGORY: CRITICAL (score≥5), WATCH (score 3-4), STABLE (score 1-2)
- JOB COSTS STATUS: PAID | PENDING (awaiting PM approval) | OVERDUE (lien risk)
- OUTSTANDING: INVOICE_AMOUNT minus PAID_AMOUNT already received

RESPONSE RULES:
- Lead with the single most critical finding.
- Reference exact project names and dollar amounts from the data.
- Flag over-budget projects with ⚠️  and overdue (lien risk) payments with 🔴
- Format dollar amounts as $X,XXX (with commas).
- End every response with: RECOMMENDED ACTION: [specific next step and owner name]
- Keep the executive summary under 180 words."""


def ask_demo_analyst(question: str, projects_df: pd.DataFrame, job_costs_df: pd.DataFrame):
    """Streams Claude's response using the DataFrames as full context."""
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        yield "⚠️ ANTHROPIC_API_KEY not set. Add it to your .env file."
        return

    client = anthropic.Anthropic(api_key=api_key)
    system = _build_system_prompt(projects_df, job_costs_df)

    with client.messages.stream(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        system=system,
        messages=[{"role": "user", "content": question}],
    ) as stream:
        for text in stream.text_stream:
            yield text


# ── Load data ─────────────────────────────────────────────────────────────────
projects, job_costs = load_data()
kpis                = compute_kpis(projects, job_costs)
budget_df, risk_df, pm_df = compute_charts(projects, job_costs)

# ── Header ────────────────────────────────────────────────────────────────────
st.markdown(f"""
<div class="ciq-header">
  <div class="ciq-logo">{LOGO_SVG}</div>
  <div class="ciq-brand">
    <div class="ciq-name">ConstructIQ <span class="demo-badge">DEMO</span></div>
    <div class="ciq-sub">Project Intelligence Platform · CSV mode</div>
  </div>
  <div class="ciq-company">Apex Build Co &nbsp;·&nbsp; Colorado</div>
</div>
""", unsafe_allow_html=True)

# ── KPI cards ─────────────────────────────────────────────────────────────────
st.markdown('<div class="section-title">Project Overview</div>', unsafe_allow_html=True)

k1, k2, k3, k4, k5 = st.columns(5)

with k1:
    st.markdown(f"""
    <div class="kpi-wrap">
      <div class="kpi-val">{kpis['total_projects']}</div>
      <div class="kpi-lbl">Active Projects</div>
    </div>""", unsafe_allow_html=True)

with k2:
    st.markdown(f"""
    <div class="kpi-wrap">
      <div class="kpi-val-red">{kpis['critical_count']}</div>
      <div class="kpi-lbl">Critical Risk</div>
      <div class="kpi-badge-red">Needs attention</div>
    </div>""", unsafe_allow_html=True)

with k3:
    st.markdown(f"""
    <div class="kpi-wrap">
      <div class="kpi-val-ora">{kpis['over_budget_count']}</div>
      <div class="kpi-lbl">Over Budget</div>
      <div class="kpi-badge-ora">Budget breach</div>
    </div>""", unsafe_allow_html=True)

with k4:
    v = kpis['total_outstanding']
    fmt = f"${v/1_000_000:.1f}M" if v >= 1_000_000 else f"${v:,.0f}"
    st.markdown(f"""
    <div class="kpi-wrap">
      <div class="kpi-val">{fmt}</div>
      <div class="kpi-lbl">Outstanding Costs</div>
    </div>""", unsafe_allow_html=True)

with k5:
    st.markdown(f"""
    <div class="kpi-wrap">
      <div class="kpi-val-ora">{kpis['pending_approvals']}</div>
      <div class="kpi-lbl">Pending Approvals</div>
    </div>""", unsafe_allow_html=True)

st.markdown("<div style='height:14px'></div>", unsafe_allow_html=True)

# ── Charts ────────────────────────────────────────────────────────────────────
ch1, ch2, ch3 = st.columns([5, 3, 4])

# Chart 1 — Budget vs Actual
with ch1:
    st.markdown('<div class="chart-card">', unsafe_allow_html=True)
    st.markdown('<div class="section-title">Budget vs Actual Cost ($K)</div>', unsafe_allow_html=True)
    bar_colors = ["#DC2626" if v else "#E8720C" for v in budget_df["IS_OVER_BUDGET"].tolist()]
    fig1 = go.Figure()
    fig1.add_trace(go.Bar(
        name="Budget", y=budget_df["PROJECT_NAME"], x=budget_df["BUDGET_K"],
        orientation="h", marker_color="#E5E7EB", marker_line_width=0,
    ))
    fig1.add_trace(go.Bar(
        name="Actual", y=budget_df["PROJECT_NAME"], x=budget_df["ACTUAL_K"],
        orientation="h", marker_color=bar_colors, marker_line_width=0,
    ))
    fig1.update_layout(
        barmode="overlay", height=240,
        margin=dict(l=0, r=10, t=4, b=0),
        paper_bgcolor="white", plot_bgcolor="white",
        font=dict(size=10, color="#374151"),
        legend=dict(orientation="h", yanchor="bottom", y=1.0, xanchor="right", x=1, font=dict(size=9)),
        xaxis=dict(showgrid=True, gridcolor="#F3F4F6", zeroline=False,
                   tickfont=dict(size=9), tickprefix="$", ticksuffix="K"),
        yaxis=dict(tickfont=dict(size=9)),
    )
    st.plotly_chart(fig1, use_container_width=True, config={"displayModeBar": False})
    st.markdown("</div>", unsafe_allow_html=True)

# Chart 2 — Risk donut
with ch2:
    st.markdown('<div class="chart-card">', unsafe_allow_html=True)
    st.markdown('<div class="section-title">Risk Breakdown</div>', unsafe_allow_html=True)
    color_map = {"CRITICAL": "#DC2626", "WATCH": "#E8720C", "STABLE": "#16A34A"}
    colors = [color_map.get(c, "#9CA3AF") for c in risk_df["RISK_SCORE_CATEGORY"].tolist()]
    fig2 = go.Figure(go.Pie(
        labels=risk_df["RISK_SCORE_CATEGORY"], values=risk_df["CNT"],
        hole=0.6, marker_colors=colors, textfont_size=10, showlegend=True,
    ))
    fig2.update_layout(
        height=240, margin=dict(l=0, r=0, t=4, b=0),
        paper_bgcolor="white", font=dict(size=10, color="#374151"),
        legend=dict(orientation="h", yanchor="bottom", y=-0.15, font=dict(size=9)),
    )
    st.plotly_chart(fig2, use_container_width=True, config={"displayModeBar": False})
    st.markdown("</div>", unsafe_allow_html=True)

# Chart 3 — Pending by PM
with ch3:
    st.markdown('<div class="chart-card">', unsafe_allow_html=True)
    st.markdown('<div class="section-title">Pending Approvals by Project Manager ($)</div>', unsafe_allow_html=True)
    first_names = [n.split()[0] for n in pm_df["PROJECT_MANAGER"].tolist()]
    fig3 = go.Figure(go.Bar(
        x=first_names, y=pm_df["PENDING_AMOUNT"],
        marker_color="#E8720C", marker_line_width=0,
        text=[f"${v/1000:.0f}K" for v in pm_df["PENDING_AMOUNT"]],
        textposition="outside", textfont=dict(size=9),
    ))
    fig3.update_layout(
        height=240, margin=dict(l=0, r=10, t=20, b=0),
        paper_bgcolor="white", plot_bgcolor="white",
        font=dict(size=10, color="#374151"),
        xaxis=dict(tickfont=dict(size=9)),
        yaxis=dict(showgrid=True, gridcolor="#F3F4F6", zeroline=False,
                   tickfont=dict(size=9), tickprefix="$"),
    )
    st.plotly_chart(fig3, use_container_width=True, config={"displayModeBar": False})
    st.markdown("</div>", unsafe_allow_html=True)

# ── AI Chat section ───────────────────────────────────────────────────────────
st.markdown('<hr class="ciq-divider">', unsafe_allow_html=True)
st.markdown("""
<div class="ai-section-header">
  <span class="ai-dot"></span> Ask ConstructIQ
</div>""", unsafe_allow_html=True)

# Chat history
for msg in st.session_state.messages:
    with st.chat_message(msg["role"]):
        st.markdown(msg["content"])
        if msg.get("pandas_query"):
            with st.expander("View pandas filter", expanded=False):
                st.code(msg["pandas_query"], language="python")

# Rate limit check
limit_hit = st.session_state.question_count >= MAX_QUESTIONS

# Chat input (always rendered — disabling via state)
question = st.chat_input(
    "Ask about budgets, schedules, approvals, subcontractor payments…",
    disabled=limit_hit,
)

# Handle sidebar-button click
if st.session_state.pending_q:
    question = st.session_state.pending_q
    st.session_state.pending_q = None

# ── Sample questions ──────────────────────────────────────────────────────────
st.markdown('<div class="sq-label">Suggested questions</div>', unsafe_allow_html=True)
sq_cols = st.columns(len(SAMPLE_QUESTIONS))
for i, q in enumerate(SAMPLE_QUESTIONS):
    if sq_cols[i].button(q, key=f"sq_{i}", disabled=limit_hit):
        st.session_state.pending_q = q
        st.rerun()

# ── Rate limit banner ─────────────────────────────────────────────────────────
remaining = MAX_QUESTIONS - st.session_state.question_count
if limit_hit:
    st.markdown("""
    <div class="rate-limit-box">
      <div class="rate-limit-title">🔒 Demo limit reached</div>
      <div class="rate-limit-sub">
        You've used all 5 demo questions.<br>
        Clone the repo to run unlimited queries against your own data.
      </div>
      <br>
      <div class="rate-limit-code">git clone https://github.com/saluvala17/Vendor_Intelligence_Assistant.git</div>
    </div>
    """, unsafe_allow_html=True)
elif remaining <= 2:
    st.caption(f"⚡ {remaining} demo question{'s' if remaining != 1 else ''} remaining.")

# ── Handle question ───────────────────────────────────────────────────────────
if question and not limit_hit:
    st.session_state.question_count += 1
    hint = pandas_hint(question)

    st.session_state.messages.append({"role": "user", "content": question})
    with st.chat_message("user"):
        st.markdown(question)

    with st.chat_message("assistant"):
        full_response = ""
        with st.spinner("Analyzing…"):
            response_placeholder = st.empty()
            try:
                for chunk in ask_demo_analyst(question, projects, job_costs):
                    full_response += chunk
                    response_placeholder.markdown(full_response + "▌")
                response_placeholder.markdown(full_response)
            except Exception as e:
                full_response = f"Error: {e}"
                response_placeholder.markdown(full_response)

        with st.expander("View pandas filter", expanded=False):
            st.code(hint, language="python")

    st.session_state.messages.append({
        "role": "assistant",
        "content": full_response,
        "pandas_query": hint,
    })

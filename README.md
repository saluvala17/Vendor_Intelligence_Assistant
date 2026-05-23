# Vendor Intelligence POC

![Python](https://img.shields.io/badge/Python-3.11-3776ab?logo=python&logoColor=white)
![Snowflake](https://img.shields.io/badge/Snowflake-Data_Warehouse-29b5e8?logo=snowflake&logoColor=white)
![dbt](https://img.shields.io/badge/dbt-Core-ff694b?logo=dbt&logoColor=white)
![Claude](https://img.shields.io/badge/Claude-AI_Chatbot-8b5cf6?logo=anthropic&logoColor=white)
![Streamlit](https://img.shields.io/badge/Streamlit-App-ff4b4b?logo=streamlit&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green)

**Enterprise-grade AI-powered vendor analytics using a config-driven data pipeline.**  
Clone. Configure. Run. Have a working AI chatbot in 10 minutes.

---

## Table of Contents

1. [What This Demonstrates](#what-this-demonstrates)
2. [High-Level Flow](#high-level-flow)
3. [Component Deep Dive](#component-deep-dive)
   - [1. Config File — Single Source of Truth](#1-config-file--single-source-of-truth)
   - [2. Scripts — Bridge from YAML to Snowflake](#2-scripts--bridge-from-yaml-to-snowflake)
   - [3. Raw Data — Actual Business Data](#3-raw-data--actual-business-data)
   - [4. dbt — The Transformation Layer](#4-dbt--the-transformation-layer)
   - [5. Semantic Model — Business Vocabulary](#5-semantic-model--business-vocabulary)
   - [6. What Happens When a User Fires a Query](#6-what-happens-when-a-user-fires-a-query)
4. [Full Component Map](#full-component-map)
5. [The Config-Driven Approach](#the-config-driven-approach)
6. [Setup (10 minutes)](#setup-10-minutes)
7. [Sample Questions](#sample-questions)
8. [How to Add a New Column](#how-to-add-a-new-column)
9. [CI/CD Pipeline](#cicd-pipeline)
10. [Data Scenarios for Demos](#data-scenarios-for-demos)

---

## What This Demonstrates

| Concept | Implementation |
|---------|---------------|
| Config-driven dbt | One YAML file controls all model columns, tests, and metadata |
| CI/CD for data | GitHub Actions validates → loads config → runs dbt automatically |
| AI + SQL | Claude uses tool-use to generate SQL, execute it, and explain results |
| Semantic modeling | Vendor 360 mart exposed as a semantic layer for BI tools |
| Enterprise data patterns | Staging → Mart → AI layer with risk scoring |

---

## High-Level Flow

```
config/model_config.yml          ← EDIT THIS to add/change columns
        │
        │  git push → GitHub Actions
        ▼
scripts/validate_config.py       ← pre-flight YAML structure check
        │
        ▼
scripts/load_config_to_snowflake.py
        │  reads YAML → TRUNCATE + INSERT → Snowflake metadata table
        ▼
LEARNING_DB.RAW.DBT_MODEL_CONFIG (Snowflake metadata table, 29 rows)
LEARNING_DB.RAW.VENDOR_MASTER    (20 rows of raw vendor data)
LEARNING_DB.RAW.VENDOR_INVOICES  (50 rows of raw invoice data)
        │
        │  dbt reads RAW schema
        ▼
dbt macros/generate_model.sql    ← reads DBT_MODEL_CONFIG at compile time
        │                           generates SELECT SQL automatically
        ▼
dbt models/staging/              ← cleansed views (no data copied, live SQL)
  STG_VENDOR_MASTER              ← adds CONTRACT_DAYS_REMAINING, CREDIT_UTILIZATION_PCT
  STG_VENDOR_INVOICES            ← adds OUTSTANDING_AMOUNT, DAYS_OVERDUE, PAYMENT_BREACH
        │
        ▼
dbt models/mart/                 ← materialized tables (data stored)
  MART_VENDOR_360                ← 360 view + composite RISK_SCORE (1-6)
  MART_VENDOR_PAYMENTS           ← invoice-level with PAYMENT_PRIORITY
        │
        │  described by
        ▼
semantic/vendor_semantic_model.yaml  ← dimensions, measures, saved queries
        │
        │  Claude API reads mart tables via execute_sql tool
        ▼
app/utils/cortex_analyst.py      ← NL question → SQL → execute → interpret
        │
        ▼
app/chatbot.py (Streamlit)       ← chat UI + sidebar KPIs + SQL viewer + data table
```

---

## Component Deep Dive

### 1. Config File — Single Source of Truth

[`config/model_config.yml`](config/model_config.yml) is a YAML file that **describes** your data — column names, data types, business names, what tests to run, whether a column goes into the mart. It does **not** move data itself.

```yaml
- name: VENDOR_ID
  data_type: VARCHAR
  business_name: Vendor Identifier
  description: Unique vendor ID from procurement system
  is_pk: true           # → dbt test: not_null + unique
  is_nullable: false
  include_in_mart: true
  tests:
    not_null: true
    unique: true
    accepted_values: []
```

Think of it as a **schema registry** — one place where every team member looks to understand what columns exist and why. Every downstream component (scripts, dbt, CI/CD) reads from this single file.

---

### 2. Scripts — Bridge from YAML to Snowflake

```
model_config.yml → validate_config.py → load_config_to_snowflake.py → Snowflake
```

**`scripts/validate_config.py`** reads the YAML and enforces rules before anything touches Snowflake:
- Is every PK column marked `not_null: true`?
- Are data types only from the allowed set (VARCHAR, NUMBER, DATE...)?
- No duplicate column names within the same model?

If anything fails → exits with **code 1** → GitHub Actions stops the entire pipeline immediately.

**`scripts/load_config_to_snowflake.py`** does this under the hood:

```python
# Step 1 — Read the YAML
config = yaml.safe_load(open("config/model_config.yml"))

# Step 2 — Connect to Snowflake using .env credentials
conn = snowflake.connector.connect(account="axtjifc-gp11017", user=..., ...)

# Step 3 — TRUNCATE then INSERT (always a full refresh — idempotent)
cursor.execute("TRUNCATE TABLE LEARNING_DB.RAW.DBT_MODEL_CONFIG")

# Step 4 — One row per column (29 rows for 2 models)
for model in config["models"]:
    for column in model["columns"]:
        cursor.execute(INSERT_SQL, {
            "source_table":  "VENDOR_MASTER",
            "target_model":  "STG_VENDOR_MASTER",
            "column_name":   "VENDOR_ID",
            "data_type":     "VARCHAR",
            "is_pk":         True,
            "test_not_null": True,
            "test_unique":   True,
            ...
        })
```

**Result:** `LEARNING_DB.RAW.DBT_MODEL_CONFIG` becomes a **metadata table** inside Snowflake — 29 rows fully describing your 2 models, loaded fresh every CI/CD run.

---

### 3. Raw Data — Actual Business Data

The SQL files in [`snowflake/`](snowflake/) are **completely separate** from the config flow. They create the actual business data:

```
snowflake/02_raw_vendor_master.sql   → 20 rows of vendor data (INSERT statements)
snowflake/03_raw_vendor_invoices.sql → 50 rows of invoice data (INSERT statements)
```

These are plain `CREATE TABLE` + `INSERT` statements. You paste them into Snowflake Worksheets and run them once. This is your **raw source data** — untouched, exactly as it would come from an upstream ERP/AP system.

After running all 4 SQL files, your RAW schema contains:

```
LEARNING_DB.RAW.VENDOR_MASTER      → 20 rows (real vendor data)
LEARNING_DB.RAW.VENDOR_INVOICES    → 50 rows (real invoice data)
LEARNING_DB.RAW.DBT_MODEL_CONFIG   → 29 rows (metadata, loaded by Python script)
```

---

### 4. dbt — The Transformation Layer

dbt does **not insert data into Snowflake from Python**. It runs SQL *inside Snowflake itself*. When you run `dbt run`, dbt:

1. Reads your `.sql` model files from your laptop
2. Compiles them — resolves `{{ ref() }}` and `{{ source() }}` macros into real fully-qualified table names
3. Sends the final compiled SQL to Snowflake over the network
4. Snowflake executes it and creates the views or tables

#### How the Macro Works

[`dbt/vendor_demo/macros/generate_model.sql`](dbt/vendor_demo/macros/generate_model.sql) is a Jinja function that **queries `DBT_MODEL_CONFIG` at compile time** to build a SELECT statement automatically:

```sql
-- When called as {{ generate_staging_sql('STG_VENDOR_MASTER') }}

-- Step 1: At dbt compile time, runs this query against Snowflake:
SELECT COLUMN_NAME, DATA_TYPE, IS_PK
FROM LEARNING_DB.RAW.DBT_MODEL_CONFIG
WHERE TARGET_MODEL = 'STG_VENDOR_MASTER'

-- Step 2: Uses those results to build this SQL dynamically:
SELECT
    UPPER(TRIM(VENDOR_ID))              AS VENDOR_ID,
    UPPER(TRIM(VENDOR_NAME))            AS VENDOR_NAME,
    CAST(CREDIT_LIMIT AS NUMBER(15,2))  AS CREDIT_LIMIT,
    CAST(CONTRACT_END AS DATE)          AS CONTRACT_END,
    ...
    CURRENT_TIMESTAMP() AS DBT_LOADED_AT
FROM LEARNING_DB.RAW.VENDOR_MASTER
```

**The macro reads config → generates SQL.** Add a column to the YAML → load it to Snowflake → the macro picks it up automatically on the next `dbt compile`. That is the config-driven concept in action.

#### Staging Models — Views (no data copied)

[`stg_vendor_master.sql`](dbt/vendor_demo/models/staging/stg_vendor_master.sql) is materialized as a **view** — no data is physically copied. It is a saved SQL query that adds derived columns calculated live every time you query it:

```sql
-- Raw table has: CONTRACT_END (a plain date column)
-- Staging view adds these derived columns:

DATEDIFF('day', CURRENT_DATE(), CONTRACT_END)   AS CONTRACT_DAYS_REMAINING,

ROUND((ANNUAL_SPEND / CREDIT_LIMIT) * 100, 2)   AS CREDIT_UTILIZATION_PCT,

CASE
  WHEN DATEDIFF('day', CURRENT_DATE(), CONTRACT_END) <= 90
  THEN TRUE ELSE FALSE
END                                              AS IS_EXPIRING_SOON
```

Because it is a **view**, `IS_EXPIRING_SOON` is recalculated using today's date every time someone queries it — always current, no stale data.

#### Mart Models — Tables (data physically stored)

[`mart_vendor_360.sql`](dbt/vendor_demo/models/mart/mart_vendor_360.sql) is materialized as a **table** — Snowflake stores the results physically. It JOINs both staging views and adds the composite risk score:

```sql
-- Data lineage inside the mart:
WITH invoice_aggregates AS (
    SELECT VENDOR_ID,
           SUM(OUTSTANDING_AMOUNT)   AS TOTAL_OUTSTANDING_AMOUNT,
           COUNT(INVOICE_ID)         AS INVOICE_COUNT,
           MAX(HAS_OVERDUE_INVOICES) AS HAS_OVERDUE_INVOICES
    FROM stg_vendor_invoices
    GROUP BY VENDOR_ID
)

-- Risk score formula:
CASE risk_rating
    WHEN 'HIGH'   THEN 3     -- base risk points
    WHEN 'medium' THEN 2
    ELSE               1
END
+ CASE WHEN has_overdue_invoices THEN 2 ELSE 0 END  -- overdue penalty
+ CASE WHEN is_expiring_soon     THEN 1 ELSE 0 END  -- expiry penalty
AS RISK_SCORE,

-- Human-readable category:
CASE
    WHEN RISK_SCORE >= 5 THEN 'CRITICAL'
    WHEN RISK_SCORE >= 3 THEN 'WATCH'
    ELSE                      'STABLE'
END AS RISK_SCORE_CATEGORY
```

**Full data lineage:**
```
RAW.VENDOR_MASTER    →  stg_vendor_master (view)   ↘
                                                     mart_vendor_360 (table)
RAW.VENDOR_INVOICES  →  stg_vendor_invoices (view) ↗
```

---

### 5. Semantic Model — Business Vocabulary

[`semantic/vendor_semantic_model.yaml`](semantic/vendor_semantic_model.yaml) sits on top of `mart_vendor_360` and is a **declaration file** — it does not run automatically. It is read by BI tools (Tableau, Looker, dbt MetricFlow, Snowflake Semantic Layer) to answer metric questions consistently.

```yaml
model: ref('mart_vendor_360')

dimensions:              # how to slice and group
  - name: risk_rating
  - name: account_manager
  - name: vendor_type

measures:                # what to calculate — defined once, used everywhere
  - name: total_outstanding_amount
    agg: sum
    expr: TOTAL_OUTSTANDING_AMOUNT

  - name: avg_credit_utilization
    agg: average
    expr: CREDIT_UTILIZATION_PCT

saved_queries:           # pre-built, reusable query templates
  - name: critical_vendor_watchlist
    where: risk_score_category = 'CRITICAL'
```

**Why it matters:** Without a semantic layer, two analysts might write different SQL for "total outstanding amount" and get different numbers. The semantic model is the single agreed-upon definition. Every tool that reads it uses the same formula.

In this POC the semantic model also documents the **business intent** behind every measure and dimension — making the mart self-describing for any new team member.

---

### 6. What Happens When a User Fires a Query

Here is the complete real-time flow for: *"Which HIGH risk vendors have overdue invoices?"*

```
User types question in Streamlit
        │
        ▼
chatbot.py appends question to session_state.messages
        │
        ▼
cortex_analyst.py — ask_vendor_analyst(question)
        │
        ▼ ── API Call #1 (Claude reasons about the question) ──────────────────
        │
Anthropic API receives:
  system: "You are a senior financial analyst...
           MART_VENDOR_360 has columns: RISK_RATING,
           HAS_OVERDUE_INVOICES, TOTAL_OUTSTANDING_AMOUNT..."
  user:   "Which HIGH risk vendors have overdue invoices?"

Claude thinks: "I need to query MART_VENDOR_360 filtering
               on RISK_RATING = 'HIGH' and HAS_OVERDUE_INVOICES = TRUE"

Claude returns a tool_use block (NOT text yet):
{
  "type": "tool_use",
  "name": "execute_sql",
  "id": "toolu_01ABC",
  "input": {
    "sql": "SELECT VENDOR_NAME, TOTAL_OUTSTANDING_AMOUNT,
                   OVERDUE_INVOICE_COUNT, CONTRACT_END
            FROM LEARNING_DB.MART.MART_VENDOR_360
            WHERE RISK_RATING = 'HIGH'
              AND HAS_OVERDUE_INVOICES = TRUE
            ORDER BY TOTAL_OUTSTANDING_AMOUNT DESC"
  }
}
        │
        ▼ ── cortex_analyst.py intercepts the tool_use block ─────────────────
        │
snowflake_conn.py.execute_query(sql)
  → Opens Snowflake connection (cached, reused across requests)
  → Sends the SQL to Snowflake
  → Returns 3 rows (the 3 HIGH risk vendors)
  → Converted to pandas DataFrame
  → Displayed in expandable "View Raw Data" table in the UI
        │
        ▼ ── Results sent back to Claude as tool_result ────────────────────
        │
{
  "type": "tool_result",
  "tool_use_id": "toolu_01ABC",
  "content": "[
    {VENDOR_NAME: 'TECHSOLUTIONS INC',   OUTSTANDING: 285000, OVERDUE_COUNT: 1},
    {VENDOR_NAME: 'CLOUDNET SYSTEMS',    OUTSTANDING: 217000, OVERDUE_COUNT: 1},
    {VENDOR_NAME: 'OFFICE SUPPLIES DIR', OUTSTANDING: 80000,  OVERDUE_COUNT: 1}
  ]"
}
        │
        ▼ ── API Call #2 (Claude synthesizes with real data) ──────────────────
        │
Claude now has REAL numbers. Applies system prompt rules:
  - Lead with the most critical risk
  - Use exact vendor names and dollar amounts
  - Flag CRITICAL with 🔴
  - Flag HIGH risk with ⚠️
  - End with: RECOMMENDED ACTION: [specific next step]
  - Keep under 200 words
        │
        ▼
Streams text response back to chatbot.py
        │
        ▼
Streamlit renders:
  ├── Executive summary text (streamed in the chat bubble)
  ├── Expandable "View SQL"  (the exact query Claude wrote)
  └── Expandable "View Raw Data" (the pandas DataFrame from Snowflake)
```

**Key insight:** Claude never sees your password or credentials. It only sees the SQL results — plain JSON rows. The `execute_sql` tool is the **only bridge** between Claude and your database. Claude writes the SQL; your Python code executes it safely.

---

## Full Component Map

```
┌─────────────────────────────────────────────────────────────────────┐
│  config/model_config.yml                                            │
│  "Schema registry — column definitions, tests, business metadata"   │
└─────────────────┬───────────────────────────────────────────────────┘
                  │ read by
     ┌────────────▼────────────┐
     │  validate_config.py     │  Exit 1 on failure → CI/CD stops
     └────────────┬────────────┘
                  │ passes to
     ┌────────────▼──────────────────────┐
     │  load_config_to_snowflake.py      │  TRUNCATE + INSERT (full refresh)
     └────────────┬──────────────────────┘
                  │ writes to
┌─────────────────▼───────────────────────────────────────────────────┐
│  LEARNING_DB.RAW                                                    │
│  ├── DBT_MODEL_CONFIG   (29 rows — metadata)                        │
│  ├── VENDOR_MASTER      (20 rows — raw vendor data)                 │
│  └── VENDOR_INVOICES    (50 rows — raw invoice data)                │
└─────────────────┬───────────────────────────────────────────────────┘
                  │ read by dbt at compile + run time
     ┌────────────▼───────────────────────────┐
     │  macros/generate_model.sql             │
     │  Reads DBT_MODEL_CONFIG → builds SQL   │
     └────────────┬───────────────────────────┘
                  │ generates
┌─────────────────▼───────────────────────────────────────────────────┐
│  LEARNING_DB.STAGING (views — no data copied, calculated live)      │
│  ├── STG_VENDOR_MASTER    + CONTRACT_DAYS_REMAINING, IS_EXPIRING_SOON│
│  └── STG_VENDOR_INVOICES  + OUTSTANDING_AMOUNT, DAYS_OVERDUE         │
└─────────────────┬───────────────────────────────────────────────────┘
                  │ joined + aggregated by dbt mart models
┌─────────────────▼───────────────────────────────────────────────────┐
│  LEARNING_DB.MART (tables — data physically stored)                 │
│  ├── MART_VENDOR_360       RISK_SCORE + RISK_SCORE_CATEGORY          │
│  └── MART_VENDOR_PAYMENTS  PAYMENT_PRIORITY + APPROVER_ACTION        │
└─────────────────┬───────────────────────────────────────────────────┘
                  │ declared in
     ┌────────────▼──────────────────────────────────────┐
     │  semantic/vendor_semantic_model.yaml               │
     │  Dimensions, measures, saved queries for BI tools  │
     └────────────┬──────────────────────────────────────┘
                  │ queried by
     ┌────────────▼──────────────────────────────────────┐
     │  app/utils/cortex_analyst.py                       │
     │  Claude API → tool_use → execute_sql → Snowflake   │
     │  NL question → SQL → results → executive summary   │
     └────────────┬──────────────────────────────────────┘
                  │ rendered in
     ┌────────────▼──────────────────────────────────────┐
     │  app/chatbot.py  (Streamlit)                       │
     │  Sidebar KPIs + chat history + SQL viewer + table  │
     └────────────────────────────────────────────────────┘
```

---

## The Config-Driven Approach

> **Edit one YAML file. Push to GitHub. CI/CD handles everything else.**

Traditional approach: edit Snowflake DDL → edit dbt SQL → edit schema.yml → run dbt manually → update docs.

**This approach:**

```yaml
# config/model_config.yml — add this block to add a new column
- name: PAYMENT_REGION
  data_type: VARCHAR
  business_name: Payment Region
  description: Geographic region for payment processing
  is_pk: false
  is_nullable: true
  include_in_mart: true
  tests:
    not_null: false
    unique: false
    accepted_values: []
```

```bash
git add config/model_config.yml
git commit -m "feat: add PAYMENT_REGION column"
git push origin feature/add-payment-region
# GitHub Actions automatically:
#  ✓ validates the YAML
#  ✓ loads it to Snowflake DBT_MODEL_CONFIG
#  ✓ runs dbt compile + run + test
#  ✓ blocks merge if any test fails
#  ✓ full audit trail in git history
```

Zero manual SQL. Zero dbt file editing. Full audit trail in git.

---

## Prerequisites

- Python 3.11+
- A Snowflake account (free trial at [snowflake.com](https://signup.snowflake.com/))
- An Anthropic API key ([console.anthropic.com](https://console.anthropic.com/))
- dbt Core: `pip install dbt-snowflake`
- Git

---

## Setup (10 minutes)

### Step 1 — Clone the repo

```bash
git clone https://github.com/saluvala17/Vendor_Intelligence_Assistant.git
cd Vendor_Intelligence_Assistant
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

### Step 2 — Configure credentials

```bash
cp .env.example .env
# Edit .env — add your Snowflake account identifier and Anthropic API key
```

> **Never commit `.env` to version control. It is already in `.gitignore`.**

**Finding your Snowflake account identifier:**  
Log in at [app.snowflake.com](https://app.snowflake.com). Your browser URL will be:  
`https://app.snowflake.com/ORGNAME/ACCOUNTNAME/...`  
Your account identifier is: `ORGNAME-ACCOUNTNAME` (e.g. `axtjifc-gp11017`)

### Step 3 — Run SQL files in Snowflake (in order)

Open Snowflake Worksheets and run each file:

```
snowflake/01_setup_schemas.sql       ← creates LEARNING_DB + all schemas
snowflake/02_raw_vendor_master.sql   ← creates table + seeds 20 vendors
snowflake/03_raw_vendor_invoices.sql ← creates table + seeds 50 invoices
snowflake/04_grants.sql              ← sets up role permissions
```

### Step 4 — Load config metadata to Snowflake

```bash
# Dry run first — preview without connecting:
python scripts/load_config_to_snowflake.py --dry-run

# Real load:
python scripts/load_config_to_snowflake.py
# Expected: "SUCCESS: Loaded 29 columns for 2 models"
```

### Step 5 — Run dbt

```bash
cd dbt/vendor_demo

# Copy example profiles and fill in your credentials:
cp profiles.yml.example ~/.dbt/profiles.yml

dbt deps      # install dbt_utils package
dbt compile   # verify all models parse and connect
dbt run       # create STG_ views and MART_ tables in Snowflake
dbt test      # run all 31 data quality tests
```

### Step 6 — Launch the chatbot

```bash
cd ../..
streamlit run app/chatbot.py
# Open http://localhost:8501
```

---

## Sample Questions

- "Which vendors are at payment risk?"
- "What is our total outstanding AP balance?"
- "Which vendor contracts expire in 90 days?"
- "Who has the most pending invoice approvals?"
- "Show IT category spend by business unit"
- "Which HIGH risk vendors have overdue invoices?"

---

## How to Add a New Column

```bash
# 1. Edit config/model_config.yml — add column definition under the right model
# 2. Push to a feature branch:
git checkout -b feature/add-payment-region
git add config/model_config.yml
git commit -m "feat: add PAYMENT_REGION column to VENDOR_MASTER"
git push origin feature/add-payment-region

# GitHub Actions automatically:
#  ✓ validate_config.py runs — checks YAML rules
#  ✓ load_config_to_snowflake.py runs — loads fresh config to Snowflake
#  ✓ dbt compile + dbt run + dbt test — models rebuilt and tested
#  ✓ merge blocked if any test fails
#  ✓ merge allowed if all green
```

---

## View dbt Lineage

```bash
cd dbt/vendor_demo
dbt docs generate
dbt docs serve
# Open http://localhost:8080
# Explore the full DAG: RAW → STAGING → MART
```

---

## CI/CD Pipeline

On every `git push` to a `feature/*` branch or PR to `main`, GitHub Actions runs 4 jobs in sequence:

| Job | What it does | Fails if |
|-----|-------------|----------|
| `validate-config` | Checks `model_config.yml` structure | YAML is invalid, PK missing `not_null`, duplicate columns |
| `load-config` | Loads config to Snowflake `DBT_MODEL_CONFIG` | Snowflake connection fails, INSERT error |
| `dbt-run` | compile → run → test → docs generate | Any dbt model fails, any data test fails |
| `notify` | Prints success summary or failure details | (always runs) |

Add these secrets to your GitHub repo → Settings → Secrets:
- `SNOWFLAKE_ACCOUNT`
- `SNOWFLAKE_USER`
- `SNOWFLAKE_PASSWORD`
- `ANTHROPIC_API_KEY`

---

## Project Structure

```
Vendor_Intelligence_Assistant/
├── config/model_config.yml          ← single source of truth
├── scripts/
│   ├── validate_config.py           ← pre-flight YAML checker
│   ├── load_config_to_snowflake.py  ← YAML → Snowflake metadata loader
│   └── requirements.txt
├── snowflake/
│   ├── 01_setup_schemas.sql         ← create LEARNING_DB + schemas
│   ├── 02_raw_vendor_master.sql     ← 20 vendors with business scenarios
│   ├── 03_raw_vendor_invoices.sql   ← 50 invoices (8 overdue, 18 pending)
│   └── 04_grants.sql
├── dbt/vendor_demo/
│   ├── dbt_project.yml
│   ├── profiles.yml.example
│   ├── packages.yml
│   ├── macros/generate_model.sql    ← reads config table → generates SQL
│   └── models/
│       ├── staging/
│       │   ├── sources.yml
│       │   ├── schema.yml
│       │   ├── stg_vendor_master.sql
│       │   └── stg_vendor_invoices.sql
│       └── mart/
│           ├── schema.yml
│           ├── mart_vendor_payments.sql
│           └── mart_vendor_360.sql
├── semantic/vendor_semantic_model.yaml
├── app/
│   ├── chatbot.py                   ← Streamlit UI
│   └── utils/
│       ├── snowflake_conn.py        ← connection manager (cached)
│       └── cortex_analyst.py       ← Claude API + tool-use loop
├── docs/architecture.md
├── requirements.txt
├── .env.example
├── .gitignore
└── .github/workflows/dbt_ci.yml    ← 4-job CI/CD pipeline
```

---

## Data Scenarios for Demos

| Scenario | Details |
|----------|---------|
| HIGH risk + overdue | TechSolutions Inc (V001), CloudNet Systems (V003), Office Supplies Direct (V005) |
| Expiring contracts | V001 expires 2026-07-15, V003 expires 2026-06-30, V005 expires 2026-05-31 |
| Most pending approvals | Mike Davis — 6 pending invoices (most of any approver) |
| IT budget overrun | IT category total > $1.7M across all invoice statuses |
| Critical risk score | Vendors with RISK_SCORE ≥ 5 are classified CRITICAL |

---

## License

MIT — free to use, modify, and share. Attribution appreciated.

---

*Built by [Santhosh Aluvala](https://github.com/saluvala17) · Powered by Snowflake + dbt + Claude*

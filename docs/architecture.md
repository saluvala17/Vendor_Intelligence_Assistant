# Architecture — Vendor Intelligence POC

## System Overview

```
Developer edits                 CI/CD Pipeline                   Users
─────────────────               ────────────────────────         ────────────────
config/                         GitHub Actions                   Streamlit App
model_config.yml                ───────────────────              ──────────────
    │                           1. validate_config.py            chatbot.py
    │  git push                 2. load_config_to_              ↕ Claude API
    └──────────────────────────►   snowflake.py                 ↕ SQL tool use
                                3. dbt compile                  ↕
                                4. dbt run                    Snowflake MART
                                5. dbt test                   MART_VENDOR_360
                                6. dbt docs generate          MART_VENDOR_PAYMENTS
```

## Data Flow

```
┌─────────────────────────────────────────────────────────┐
│                     LEARNING_DB                          │
│                                                         │
│  RAW schema                                             │
│  ├── VENDOR_MASTER          (20 rows — source data)     │
│  ├── VENDOR_INVOICES        (50 rows — source data)     │
│  └── DBT_MODEL_CONFIG       (config metadata)           │
│                       ↓ dbt staging views               │
│  STAGING schema                                         │
│  ├── STG_VENDOR_MASTER      (cleansed + enriched view)  │
│  └── STG_VENDOR_INVOICES    (calculated metrics view)   │
│                       ↓ dbt mart tables                 │
│  MART schema                                            │
│  ├── MART_VENDOR_360        (360 view — chatbot source) │
│  └── MART_VENDOR_PAYMENTS   (payment priority table)    │
└─────────────────────────────────────────────────────────┘
```

## Config-Driven Model Generation

The core architectural insight: **config/model_config.yml is the single source of truth**.

### Without this pattern (traditional approach):
1. Developer edits Snowflake DDL
2. Developer edits dbt model SQL
3. Developer edits schema.yml tests
4. Developer edits documentation
5. Developer runs dbt manually
6. No audit trail for column additions

### With this pattern (this POC):
1. Developer edits one YAML file
2. git push → done

### How CI/CD enforces it:
```
git push feature/add-column
    │
    ├── Job 1: validate_config.py
    │     Checks YAML structure, valid data types,
    │     PK columns have not_null tests, no duplicates.
    │     FAIL → pipeline stops here.
    │
    ├── Job 2: load_config_to_snowflake.py
    │     TRUNCATE DBT_MODEL_CONFIG
    │     INSERT fresh rows from YAML
    │     FAIL → pipeline stops here.
    │
    ├── Job 3: dbt run + dbt test
    │     dbt macro reads DBT_MODEL_CONFIG at compile time.
    │     All models compiled, run, tested.
    │     FAIL → merge blocked.
    │
    └── Job 4: notify
          SUCCESS → deployment summary printed.
          FAILURE → which test failed + how to fix it.
```

## Claude API Integration

The chatbot uses Claude's tool-use capability:

```
User: "Which HIGH risk vendors have overdue invoices?"
    │
    ▼
Claude (reasoning):
  "I need to query MART_VENDOR_360 for vendors
   with RISK_RATING='HIGH' and HAS_OVERDUE_INVOICES=TRUE"
    │
    ▼ tool call: execute_sql
    │
    ▼
Snowflake executes SQL → returns JSON rows
    │
    ▼
Claude (synthesis):
  Reads actual data, names real vendors,
  applies system prompt rules (emojis, dollar formats,
  RECOMMENDED ACTION footer)
    │
    ▼
User sees executive summary with exact numbers
```

## Component Responsibilities

| Component | Responsibility |
|-----------|---------------|
| `config/model_config.yml` | Column definitions, tests, business metadata |
| `scripts/validate_config.py` | Pre-flight check before Snowflake writes |
| `scripts/load_config_to_snowflake.py` | Config → DBT_MODEL_CONFIG table |
| `dbt/macros/generate_model.sql` | Reads config table, generates SELECT SQL |
| `dbt/models/staging/` | Cleanse, type-cast, add derived columns |
| `dbt/models/mart/` | Business aggregations, risk scoring |
| `semantic/vendor_semantic_model.yaml` | Semantic layer for BI tools |
| `app/utils/cortex_analyst.py` | Claude API + SQL tool orchestration |
| `app/chatbot.py` | Streamlit UI, chat history, sidebar KPIs |
| `.github/workflows/dbt_ci.yml` | Full CI/CD pipeline |

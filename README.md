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

## What This Demonstrates

| Concept | Implementation |
|---------|---------------|
| Config-driven dbt | One YAML file controls all model columns, tests, and metadata |
| CI/CD for data | GitHub Actions validates → loads config → runs dbt automatically |
| AI + SQL | Claude uses tool-use to generate SQL, execute it, and explain results |
| Semantic modeling | Vendor 360 mart exposed as a semantic layer for BI tools |
| Enterprise data patterns | Staging → Mart → AI layer with risk scoring |

---

## Architecture

```
config/model_config.yml          ← EDIT THIS to add/change columns
        │
        │  git push → GitHub Actions
        ▼
scripts/load_config_to_snowflake.py
        │  reads YAML → generates SQL → truncates + loads
        ▼
LEARNING_DB.RAW.DBT_MODEL_CONFIG (Snowflake metadata table)
        │
        │  dbt macro reads at compile time
        ▼
dbt staging views (STG_VENDOR_MASTER, STG_VENDOR_INVOICES)
        │
        │  cleanse + enrich + derive metrics
        ▼
dbt mart tables (MART_VENDOR_360, MART_VENDOR_PAYMENTS)
        │
        │  Claude API with SQL tool-use
        ▼
Streamlit Chatbot → executive-ready AI insights
```

---

## The Config-Driven Approach

> **Edit one YAML file. Push to GitHub. CI/CD handles everything else.**

Traditional approach: edit Snowflake DDL → edit dbt SQL → edit schema.yml → run dbt manually.

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
# GitHub Actions does the rest ↑
```

Zero manual SQL. Zero dbt file editing. Full audit trail in git.

---

## Prerequisites

- Python 3.11+
- A Snowflake account (free trial at [snowflake.com](https://signup.snowflake.com/))
- An Anthropic API key ([console.anthropic.com](https://console.anthropic.com/))
- dbt Core installed: `pip install dbt-snowflake`
- Git

---

## Setup (10 minutes)

### Step 1 — Clone the repo

```bash
git clone https://github.com/saluvala17/vendor-dbt-demo.git
cd vendor-dbt-demo
pip install -r requirements.txt
```

### Step 2 — Configure credentials

```bash
cp .env.example .env
# Edit .env with your Snowflake credentials and Anthropic API key
```

> **Never commit `.env` to version control. It is in `.gitignore`.**

### Step 3 — Run SQL files in Snowflake (in order)

Open Snowflake Worksheets and run each file:

```
snowflake/01_setup_schemas.sql     ← creates database and schemas
snowflake/02_raw_vendor_master.sql ← creates + seeds 20 vendors
snowflake/03_raw_vendor_invoices.sql ← creates + seeds 50 invoices
snowflake/04_grants.sql            ← sets up permissions
```

### Step 4 — Load config metadata to Snowflake

```bash
python scripts/load_config_to_snowflake.py

# Dry run first to preview without connecting:
python scripts/load_config_to_snowflake.py --dry-run
```

### Step 5 — Run dbt

```bash
cd dbt/vendor_demo

# Copy profiles.yml.example to ~/.dbt/profiles.yml and fill in credentials
cp profiles.yml.example ~/.dbt/profiles.yml

dbt deps          # install dbt_utils package
dbt compile       # verify models compile
dbt run           # materialize staging views and mart tables
dbt test          # run all data quality tests
```

### Step 6 — Launch the chatbot

```bash
cd ../..  # back to project root
streamlit run app/chatbot.py
```

Open [http://localhost:8501](http://localhost:8501) — your AI vendor analyst is ready.

---

## Sample Questions to Ask

- "Which vendors are at payment risk?"
- "What is our total outstanding AP balance?"
- "Which vendor contracts expire in 90 days?"
- "Who has the most pending invoice approvals?"
- "Show IT category spend by business unit"
- "Which HIGH risk vendors have overdue invoices?"

---

## How to Add a New Column

```bash
# 1. Edit config/model_config.yml — add your column definition
# 2. Push to a feature branch:
git checkout -b feature/add-my-column
git add config/model_config.yml
git commit -m "feat: add MY_COLUMN to VENDOR_MASTER"
git push origin feature/add-my-column
# 3. GitHub Actions automatically:
#    ✓ validates the config
#    ✓ loads it to Snowflake
#    ✓ runs dbt compile + run + test
#    ✓ blocks merge if any test fails
```

---

## View dbt Lineage

```bash
cd dbt/vendor_demo
dbt docs generate
dbt docs serve
# Open http://localhost:8080
```

---

## Project Structure

```
vendor-intelligence-poc/
├── config/model_config.yml          ← single source of truth
├── scripts/
│   ├── validate_config.py           ← pre-flight YAML checker
│   └── load_config_to_snowflake.py  ← YAML → Snowflake loader
├── snowflake/
│   ├── 01_setup_schemas.sql
│   ├── 02_raw_vendor_master.sql     ← 20 vendors with rich scenarios
│   ├── 03_raw_vendor_invoices.sql   ← 50 invoices with business patterns
│   └── 04_grants.sql
├── dbt/vendor_demo/
│   ├── macros/generate_model.sql    ← reads config → generates SQL
│   └── models/
│       ├── staging/                 ← cleansed views
│       └── mart/                    ← business-ready tables
├── semantic/vendor_semantic_model.yaml
├── app/
│   ├── chatbot.py                   ← Streamlit UI
│   └── utils/
│       ├── snowflake_conn.py        ← connection manager
│       └── cortex_analyst.py       ← Claude API + tool use
├── docs/architecture.md
└── .github/workflows/dbt_ci.yml    ← CI/CD pipeline
```

---

## CI/CD Pipeline

On every `git push` to a `feature/*` branch or PR to `main`:

1. **validate-config** — checks `model_config.yml` structure
2. **load-config** — loads config to Snowflake using GitHub Secrets
3. **dbt-run** — compile → run → test → docs generate
4. **notify** — prints success summary or failure details

Add these secrets to your GitHub repo settings:
- `SNOWFLAKE_ACCOUNT`
- `SNOWFLAKE_USER`
- `SNOWFLAKE_PASSWORD`
- `ANTHROPIC_API_KEY`

---

## Data Scenarios (for demos)

| Scenario | Details |
|----------|---------|
| HIGH risk + overdue | TechSolutions Inc (V001), CloudNet Systems (V003), Office Supplies Direct (V005) |
| Expiring contracts | V001 expires 2026-07-15, V003 expires 2026-06-30, V005 expires 2026-05-31 |
| Most pending approvals | Mike Davis has 6 pending invoices |
| IT budget overrun | IT category total spend > $1.7M across 50 invoices |
| Critical risk score | Vendors with RISK_SCORE ≥ 5 = CRITICAL |

---

## License

MIT — free to use, modify, and share. Attribution appreciated.

---

*Built by [Santhosh Aluvala](https://github.com/saluvala17) · Powered by Snowflake + dbt + Claude*

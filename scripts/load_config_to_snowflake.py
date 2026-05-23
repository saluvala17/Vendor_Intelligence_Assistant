"""
Reads config/model_config.yml and loads column metadata to
LEARNING_DB.RAW.DBT_MODEL_CONFIG in Snowflake.

Truncates and fully reloads the table on every run (idempotent).
Exits with code 1 on any error so CI/CD fails and blocks deployment.

Run: python scripts/load_config_to_snowflake.py
Run: python scripts/load_config_to_snowflake.py --dry-run
Run: python scripts/load_config_to_snowflake.py --env-file .env.staging
"""

import sys
import os
import json
import yaml
import argparse

try:
    import snowflake.connector
    from dotenv import load_dotenv
except ImportError as e:
    print(f"ERROR: Missing dependency: {e}")
    print("Run: pip install -r scripts/requirements.txt")
    sys.exit(1)

CREATE_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS LEARNING_DB.RAW.DBT_MODEL_CONFIG (
    SOURCE_SCHEMA        VARCHAR,
    SOURCE_TABLE         VARCHAR,
    TARGET_SCHEMA        VARCHAR,
    TARGET_MODEL         VARCHAR,
    MATERIALIZATION      VARCHAR,
    UNIQUE_KEY           VARCHAR,
    LOAD_TYPE            VARCHAR,
    IS_ACTIVE            BOOLEAN,
    COLUMN_NAME          VARCHAR,
    DATA_TYPE            VARCHAR,
    BUSINESS_NAME        VARCHAR,
    DESCRIPTION          VARCHAR,
    IS_PK                BOOLEAN,
    IS_NULLABLE          BOOLEAN,
    INCLUDE_IN_MART      BOOLEAN,
    TEST_NOT_NULL        BOOLEAN,
    TEST_UNIQUE          BOOLEAN,
    TEST_ACCEPTED_VALUES VARCHAR,
    LOADED_AT            TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
"""

TRUNCATE_SQL = "TRUNCATE TABLE LEARNING_DB.RAW.DBT_MODEL_CONFIG"

INSERT_SQL = """
INSERT INTO LEARNING_DB.RAW.DBT_MODEL_CONFIG (
    SOURCE_SCHEMA, SOURCE_TABLE, TARGET_SCHEMA, TARGET_MODEL,
    MATERIALIZATION, UNIQUE_KEY, LOAD_TYPE, IS_ACTIVE,
    COLUMN_NAME, DATA_TYPE, BUSINESS_NAME, DESCRIPTION,
    IS_PK, IS_NULLABLE, INCLUDE_IN_MART,
    TEST_NOT_NULL, TEST_UNIQUE, TEST_ACCEPTED_VALUES
) VALUES (
    %(source_schema)s, %(source_table)s, %(target_schema)s, %(target_model)s,
    %(materialization)s, %(unique_key)s, %(load_type)s, %(is_active)s,
    %(column_name)s, %(data_type)s, %(business_name)s, %(description)s,
    %(is_pk)s, %(is_nullable)s, %(include_in_mart)s,
    %(test_not_null)s, %(test_unique)s, %(test_accepted_values)s
)
"""

REQUIRED_ENV_VARS = [
    "SNOWFLAKE_ACCOUNT",
    "SNOWFLAKE_USER",
    "SNOWFLAKE_PASSWORD",
    "SNOWFLAKE_WAREHOUSE",
    "SNOWFLAKE_DATABASE",
    "SNOWFLAKE_ROLE",
]


def load_yaml(config_path: str) -> dict:
    try:
        with open(config_path) as f:
            return yaml.safe_load(f)
    except FileNotFoundError:
        print(f"ERROR: Config file not found: {config_path}")
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"ERROR: Invalid YAML in {config_path}: {e}")
        sys.exit(1)


def build_rows(config: dict) -> list[dict]:
    rows = []
    for model in config.get("models", []):
        if not model.get("is_active", True):
            continue
        base = {
            "source_schema": model["source_schema"],
            "source_table": model["source_table"],
            "target_schema": model.get("target_schema", "STAGING"),
            "target_model": model["target_model"],
            "materialization": model["materialization"],
            "unique_key": model.get("unique_key", ""),
            "load_type": model.get("load_type", "FULL"),
            "is_active": model.get("is_active", True),
        }
        for col in model.get("columns", []):
            tests = col.get("tests", {})
            accepted = tests.get("accepted_values", [])
            rows.append({
                **base,
                "column_name": col["name"],
                "data_type": col["data_type"],
                "business_name": col["business_name"],
                "description": col.get("description", ""),
                "is_pk": col.get("is_pk", False),
                "is_nullable": col.get("is_nullable", True),
                "include_in_mart": col.get("include_in_mart", True),
                "test_not_null": tests.get("not_null", False),
                "test_unique": tests.get("unique", False),
                "test_accepted_values": json.dumps(accepted),
            })
    return rows


def print_dry_run(rows: list[dict]) -> None:
    print("=" * 60)
    print("DRY RUN — No Snowflake connection made")
    print("=" * 60)
    print("\n[SQL] CREATE TABLE IF NOT EXISTS LEARNING_DB.RAW.DBT_MODEL_CONFIG (...)")
    print("[SQL] TRUNCATE TABLE LEARNING_DB.RAW.DBT_MODEL_CONFIG")
    print(f"\n[SQL] {len(rows)} INSERT statements would execute:\n")
    model_names = sorted({r["target_model"] for r in rows})
    for model in model_names:
        cols = [r["column_name"] for r in rows if r["target_model"] == model]
        print(f"  {model}: {len(cols)} columns")
        for col in cols[:5]:
            print(f"    - {col}")
        if len(cols) > 5:
            print(f"    ... and {len(cols) - 5} more")
    print(f"\nTotal: {len(rows)} rows across {len(model_names)} models")


def main():
    parser = argparse.ArgumentParser(
        description="Load model_config.yml metadata to Snowflake DBT_MODEL_CONFIG table"
    )
    parser.add_argument(
        "--env-file",
        default=".env",
        help="Path to .env file (default: .env)",
    )
    parser.add_argument(
        "--config",
        default="config/model_config.yml",
        help="Path to model_config.yml (default: config/model_config.yml)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print SQL without executing against Snowflake",
    )
    args = parser.parse_args()

    config = load_yaml(args.config)
    rows = build_rows(config)

    if not rows:
        print("ERROR: No active columns found in config. Nothing to load.")
        sys.exit(1)

    if args.dry_run:
        print_dry_run(rows)
        return

    load_dotenv(args.env_file)

    missing = [v for v in REQUIRED_ENV_VARS if not os.getenv(v)]
    if missing:
        print(f"ERROR: Missing required environment variables: {missing}")
        print(f"Copy .env.example to .env and fill in your credentials.")
        sys.exit(1)

    try:
        conn = snowflake.connector.connect(
            account=os.getenv("SNOWFLAKE_ACCOUNT"),
            user=os.getenv("SNOWFLAKE_USER"),
            password=os.getenv("SNOWFLAKE_PASSWORD"),
            warehouse=os.getenv("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH"),
            database=os.getenv("SNOWFLAKE_DATABASE", "LEARNING_DB"),
            role=os.getenv("SNOWFLAKE_ROLE", "SYSADMIN"),
            schema="RAW",
        )
        cursor = conn.cursor()

        print(f"Connected to Snowflake: {os.getenv('SNOWFLAKE_ACCOUNT')}")
        print("Creating DBT_MODEL_CONFIG table if not exists...")
        cursor.execute(CREATE_TABLE_SQL)

        print("Truncating existing config rows (full refresh)...")
        cursor.execute(TRUNCATE_SQL)

        model_names = sorted({r["target_model"] for r in rows})
        print(f"Loading {len(rows)} rows for {len(model_names)} models...")

        for row in rows:
            cursor.execute(INSERT_SQL, row)

        conn.commit()
        cursor.close()
        conn.close()

        print(f"\nSUCCESS: Loaded {len(rows)} columns for {len(model_names)} models")
        for model in model_names:
            count = sum(1 for r in rows if r["target_model"] == model)
            print(f"  {model}: {count} columns")

    except snowflake.connector.errors.DatabaseError as e:
        print(f"ERROR: Snowflake error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: Unexpected failure: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()

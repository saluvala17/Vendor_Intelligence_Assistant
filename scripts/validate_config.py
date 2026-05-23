"""
Validates config/model_config.yml structure before loading to Snowflake.
Exit code 0 = valid. Exit code 1 = invalid.

Run: python scripts/validate_config.py
Run: python scripts/validate_config.py --config path/to/model_config.yml
"""

import sys
import yaml
import argparse

VALID_MATERIALIZATIONS = {"view", "table", "incremental"}
VALID_DATA_TYPES = {"VARCHAR", "NUMBER", "DATE", "TIMESTAMP", "BOOLEAN", "FLOAT"}
REQUIRED_MODEL_FIELDS = {"source_schema", "source_table", "target_model", "materialization"}
REQUIRED_COLUMN_FIELDS = {"name", "data_type", "business_name"}


def validate_config(config_path: str) -> bool:
    errors = []

    try:
        with open(config_path) as f:
            config = yaml.safe_load(f)
    except FileNotFoundError:
        print(f"ERROR: Config file not found: {config_path}")
        return False
    except yaml.YAMLError as e:
        print(f"ERROR: Invalid YAML syntax: {e}")
        return False

    if not isinstance(config, dict):
        print("ERROR: Config file must be a YAML mapping at the top level")
        return False

    if "version" not in config:
        errors.append("ERROR: Missing required top-level field: 'version'")

    if "models" not in config or not config.get("models"):
        errors.append("ERROR: 'models' list is missing or empty")
        for err in errors:
            print(err)
        return False

    for model in config["models"]:
        model_name = model.get("source_table", "UNKNOWN")

        for field in REQUIRED_MODEL_FIELDS:
            if field not in model:
                errors.append(
                    f"ERROR: Model '{model_name}' missing required field: '{field}'"
                )

        if "materialization" in model:
            if model["materialization"] not in VALID_MATERIALIZATIONS:
                errors.append(
                    f"ERROR: Model '{model_name}' has invalid materialization "
                    f"'{model['materialization']}'. Must be one of: {sorted(VALID_MATERIALIZATIONS)}"
                )

        if "columns" not in model or not model.get("columns"):
            errors.append(f"ERROR: Model '{model_name}' has no columns defined")
            continue

        seen_columns = set()
        for col in model["columns"]:
            col_name = col.get("name", "UNKNOWN")

            for field in REQUIRED_COLUMN_FIELDS:
                if field not in col:
                    errors.append(
                        f"ERROR: Column '{col_name}' in '{model_name}' "
                        f"missing required field: '{field}'"
                    )

            if "data_type" in col and col["data_type"] not in VALID_DATA_TYPES:
                errors.append(
                    f"ERROR: Column '{col_name}' in '{model_name}' has invalid "
                    f"data_type '{col['data_type']}'. Must be one of: {sorted(VALID_DATA_TYPES)}"
                )

            if col_name in seen_columns:
                errors.append(
                    f"ERROR: Duplicate column name '{col_name}' in model '{model_name}'"
                )
            seen_columns.add(col_name)

            tests = col.get("tests", {})
            if col.get("is_pk", False) and not tests.get("not_null", False):
                errors.append(
                    f"ERROR: Column '{col_name}' in '{model_name}' "
                    f"is marked is_pk=true but test_not_null=false"
                )

    if errors:
        for err in errors:
            print(err)
        print(f"\nValidation FAILED: {len(errors)} error(s) found in {config_path}")
        return False

    model_count = len(config["models"])
    total_cols = sum(len(m.get("columns", [])) for m in config["models"])
    print(f"Validation PASSED: {model_count} models, {total_cols} columns — {config_path}")
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Validate model_config.yml before loading to Snowflake"
    )
    parser.add_argument(
        "--config",
        default="config/model_config.yml",
        help="Path to model_config.yml (default: config/model_config.yml)",
    )
    args = parser.parse_args()

    success = validate_config(args.config)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()

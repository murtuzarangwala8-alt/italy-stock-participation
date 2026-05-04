"""
Validation checks for the SHIW 2022 stock market participation project.
"""

from pathlib import Path

import numpy as np
import pandas as pd


DATA_DIR = Path(r"C:\Users\murta\Desktop\local pro\ind22_stata\STATA")
OUT_DIR = Path(r"C:\Users\murta\Documents\Codex\2026-05-04\documentclass-12pt-article-usepackage-utf8-inputenc\output")


def read_dta(name):
    return pd.read_stata(DATA_DIR / name, convert_categoricals=False)


def main():
    q22a = read_dta("q22a.dta")
    rfam = read_dta("rfam22.dta")
    q22c2 = read_dta("q22c2.dta")
    carcom = read_dta("carcom22.dta")
    analysis = pd.read_csv(OUT_DIR / "analysis_dataset.csv")

    checks = []

    for name, df in [
        ("q22a", q22a),
        ("rfam22", rfam),
        ("q22c2", q22c2),
        ("carcom22", carcom),
        ("analysis_dataset", analysis),
    ]:
        checks.append(
            {
                "check": f"{name}: row count",
                "value": len(df),
                "status": "INFO",
            }
        )
        if "nquest" in df.columns:
            checks.append(
                {
                    "check": f"{name}: unique household IDs",
                    "value": df["nquest"].nunique(),
                    "status": "INFO",
                }
            )

    household_ids = set(q22a["nquest"])
    for name, df in [("rfam22", rfam), ("q22c2", q22c2)]:
        missing_from_file = len(household_ids - set(df["nquest"]))
        checks.append(
            {
                "check": f"households in q22a missing from {name}",
                "value": missing_from_file,
                "status": "PASS" if missing_from_file == 0 else "WARN",
            }
        )

    head = carcom.loc[carcom["parent"] == 1].copy()
    duplicate_heads = int(head.duplicated("nquest").sum())
    missing_heads = len(household_ids - set(head["nquest"]))
    checks.extend(
        [
            {
                "check": "duplicate household heads in carcom22",
                "value": duplicate_heads,
                "status": "PASS" if duplicate_heads == 0 else "WARN",
            },
            {
                "check": "households missing a household head",
                "value": missing_heads,
                "status": "PASS" if missing_heads == 0 else "WARN",
            },
        ]
    )

    impossible_income = int((analysis["income"] <= 0).sum())
    impossible_weight = int((analysis["weight"] <= 0).sum())
    impossible_age = int(((analysis["age"] < 18) | (analysis["age"] > 100)).sum())
    checks.extend(
        [
            {
                "check": "analysis income <= 0",
                "value": impossible_income,
                "status": "PASS" if impossible_income == 0 else "FAIL",
            },
            {
                "check": "analysis weight <= 0",
                "value": impossible_weight,
                "status": "PASS" if impossible_weight == 0 else "FAIL",
            },
            {
                "check": "analysis age outside 18-100",
                "value": impossible_age,
                "status": "PASS" if impossible_age == 0 else "WARN",
            },
        ]
    )

    required = [
        "stock_participation",
        "income",
        "education",
        "region",
        "age",
        "household_size",
        "weight",
    ]
    for col in required:
        missing = int(analysis[col].isna().sum())
        checks.append(
            {
                "check": f"analysis missing {col}",
                "value": missing,
                "status": "PASS" if missing == 0 else "FAIL",
            }
        )

    raw_assets = q22c2[
        ["nquest", "pos_d3", "pos_d4", "pos_e1", "pos_e2", "pos_f2"]
    ].copy()
    raw_assets["recomputed_participation"] = (
        (raw_assets["pos_d3"] == 1)
        | (raw_assets["pos_d4"] == 1)
        | (raw_assets["pos_e1"] == 1)
        | (raw_assets["pos_e2"] == 1)
        | (raw_assets["pos_f2"] == 1)
    ).astype(int)
    comparison = analysis[["nquest", "stock_participation"]].merge(raw_assets, on="nquest")
    mismatches = int(
        (comparison["stock_participation"] != comparison["recomputed_participation"]).sum()
    )
    checks.append(
        {
            "check": "stock_participation matches raw asset columns",
            "value": mismatches,
            "status": "PASS" if mismatches == 0 else "FAIL",
        }
    )

    validation = pd.DataFrame(checks)
    validation.to_csv(OUT_DIR / "validation_report.csv", index=False)

    print(validation.to_string(index=False))
    print(f"\nSaved validation report to {OUT_DIR / 'validation_report.csv'}")


if __name__ == "__main__":
    main()


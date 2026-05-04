"""
Print the main results and a short summary of the SHIW stock participation code.

Run after analysis_stock_participation.py.
"""

from pathlib import Path

import pandas as pd


OUT_DIR = Path(r"C:\Users\murta\Documents\Codex\2026-05-04\documentclass-12pt-article-usepackage-utf8-inputenc\output")


def pct(x):
    return f"{100 * x:.2f}%"


def main():
    overall = pd.read_csv(OUT_DIR / "summary_overall.csv")
    by_education = pd.read_csv(OUT_DIR / "summary_by_education.csv")
    by_region = pd.read_csv(OUT_DIR / "summary_by_region.csv")
    ape = pd.read_csv(OUT_DIR / "average_partial_effects.csv")
    results = pd.read_csv(OUT_DIR / "probit_results.csv")

    main_model = results.loc[results["outcome"] == "stock_participation"].copy()
    important_terms = [
        "log_income",
        "education_Lower secondary",
        "education_Upper secondary",
        "education_University",
        "region_Centre",
        "region_South and Islands",
        "household_size",
        "female_head",
    ]
    main_model = main_model.loc[main_model["term"].isin(important_terms)]

    print("\n" + "=" * 72)
    print("PROJECT RESULTS: HOUSEHOLD STOCK MARKET PARTICIPATION IN ITALY")
    print("=" * 72)

    print("\n1. Overall Sample")
    print(f"Households used: {int(overall.loc[0, 'households']):,}")
    print(f"Weighted stock market participation rate: {pct(overall.loc[0, 'weighted_participation_rate'])}")
    print(f"Median household income: EUR {overall.loc[0, 'median_income']:,.0f}")
    print(f"Weighted mean age of household head: {overall.loc[0, 'mean_age']:.1f}")

    print("\n2. Participation by Education")
    for _, row in by_education.sort_values("weighted_participation_rate").iterrows():
        print(
            f"{row['education']}: "
            f"{pct(row['weighted_participation_rate'])}, "
            f"median income EUR {row['median_income']:,.0f}"
        )

    print("\n3. Participation by Region")
    for _, row in by_region.sort_values("weighted_participation_rate", ascending=False).iterrows():
        print(
            f"{row['region']}: "
            f"{pct(row['weighted_participation_rate'])}, "
            f"median income EUR {row['median_income']:,.0f}"
        )

    print("\n4. Main Probit Model Coefficients")
    print("Positive coefficient means higher probability of participation.")
    for _, row in main_model.iterrows():
        stars = "***" if row["p_value"] < 0.01 else "**" if row["p_value"] < 0.05 else "*" if row["p_value"] < 0.10 else ""
        print(
            f"{row['term']}: "
            f"coef = {row['estimate']:.4f}, "
            f"std. error = {row['std_error']:.4f}, "
            f"p-value = {row['p_value']:.4g} {stars}"
        )

    print("\n5. Average Partial Effects")
    print("These are easier to interpret than probit coefficients.")
    for _, row in ape.iterrows():
        print(f"{row['variable']}: {pct(row['average_partial_effect'])}")

    print("\n6. Short Interpretation")
    print(
        "The results support the hypothesis: higher income and higher education "
        "are both associated with a higher probability of owning stocks, mutual "
        "funds, ETFs, or similar financial assets."
    )
    print(
        "University-educated households have a much higher predicted participation "
        "probability than households with primary education or less. Participation "
        "is also lower in the South and Islands compared with the North."
    )

    print("\n7. Summary of What the Code Does")
    print("Step 1: Reads SHIW 2022 Stata files from your data folder.")
    print("Step 2: Merges household, income, asset, and demographic files by nquest.")
    print("Step 3: Creates stock_participation from POS_D3, POS_D4, POS_E1, POS_E2, and POS_F2.")
    print("Step 4: Cleans missing or invalid observations.")
    print("Step 5: Estimates weighted probit models.")
    print("Step 6: Exports tables, marginal effects, validation checks, and graphs.")

    print("\nOutput folder:")
    print(OUT_DIR)
    print("=" * 72 + "\n")


if __name__ == "__main__":
    main()


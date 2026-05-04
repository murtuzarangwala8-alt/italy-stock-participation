"""
Determinants of Household Stock Market Participation in Italy

This Python script reads the SHIW 2022 Stata files from the user's folder,
constructs the analysis dataset, estimates weighted probit models, and exports
tables and figures for the final project.
"""

from pathlib import Path

import numpy as np
import pandas as pd
from scipy.optimize import minimize
from scipy.stats import norm
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt


DATA_DIR = Path(r"C:\Users\murta\Desktop\local pro\ind22_stata\STATA")
OUT_DIR = Path(r"C:\Users\murta\Documents\Codex\2026-05-04\documentclass-12pt-article-usepackage-utf8-inputenc\output")
OUT_DIR.mkdir(exist_ok=True)


def read_dta(name):
    return pd.read_stata(DATA_DIR / name, convert_categoricals=False)


def build_dataset():
    households = read_dta("q22a.dta")[["nquest", "ncomp", "pesofit"]].rename(
        columns={"ncomp": "household_size", "pesofit": "weight"}
    )

    income = read_dta("rfam22.dta")[["nquest", "y"]].rename(columns={"y": "income"})

    assets = read_dta("q22c2.dta")[
        ["nquest", "pos_b", "pos_d3", "pos_d4", "pos_e1", "pos_e2", "pos_f2"]
    ].copy()
    assets["managed_savings"] = (assets["pos_b"] == 1).astype(int)
    assets["mutual_fund_or_etf"] = ((assets["pos_d3"] == 1) | (assets["pos_d4"] == 1)).astype(int)
    assets["direct_listed_stock"] = (assets["pos_e1"] == 1).astype(int)
    assets["stock_participation"] = (
        (assets["pos_d3"] == 1)
        | (assets["pos_d4"] == 1)
        | (assets["pos_e1"] == 1)
        | (assets["pos_e2"] == 1)
        | (assets["pos_f2"] == 1)
    ).astype(int)
    assets = assets[
        [
            "nquest",
            "managed_savings",
            "mutual_fund_or_etf",
            "direct_listed_stock",
            "stock_participation",
        ]
    ]

    head = read_dta("carcom22.dta")
    head = head.loc[head["parent"] == 1, ["nquest", "eta", "studio", "area3", "sex"]].copy()
    head = head.rename(columns={"eta": "age", "studio": "education_raw", "area3": "area3_raw"})
    head["female_head"] = (head["sex"] == 2).astype(int)
    head["education"] = np.select(
        [
            head["education_raw"].isin([1, 2]),
            head["education_raw"].eq(3),
            head["education_raw"].isin([4, 5, 6]),
            head["education_raw"].isin([7, 8]),
        ],
        ["Primary or less", "Lower secondary", "Upper secondary", "University"],
        default=None,
    )
    head["region"] = np.select(
        [head["area3_raw"].eq(1), head["area3_raw"].eq(2), head["area3_raw"].eq(3)],
        ["North", "Centre", "South and Islands"],
        default=None,
    )
    head = head[["nquest", "age", "education", "region", "female_head"]]

    df = households.merge(income, on="nquest", how="left")
    df = df.merge(assets, on="nquest", how="left")
    df = df.merge(head, on="nquest", how="left")
    df = df.loc[df["income"] > 0].copy()
    df["log_income"] = np.log(df["income"])
    df["age_centered"] = df["age"] - 55
    df["age_centered_squared"] = df["age_centered"] ** 2

    keep = [
        "nquest",
        "stock_participation",
        "mutual_fund_or_etf",
        "direct_listed_stock",
        "income",
        "log_income",
        "education",
        "age",
        "age_centered",
        "age_centered_squared",
        "region",
        "household_size",
        "female_head",
        "weight",
    ]
    df = df[keep].dropna()
    df = df.loc[(df["income"] > 0) & (df["weight"] > 0)].copy()
    return df


def design_matrix(df):
    base = df[
        ["log_income", "age_centered", "age_centered_squared", "household_size", "female_head"]
    ].copy()
    education = pd.Categorical(
        df["education"],
        categories=["Primary or less", "Lower secondary", "Upper secondary", "University"],
        ordered=True,
    )
    region = pd.Categorical(
        df["region"],
        categories=["North", "Centre", "South and Islands"],
        ordered=False,
    )
    dummies = pd.get_dummies(
        pd.DataFrame({"education": education, "region": region}, index=df.index),
        drop_first=True,
        dtype=float,
    )
    x = pd.concat([pd.Series(1.0, index=df.index, name="Intercept"), base, dummies], axis=1)
    return x.astype(float)


def fit_weighted_probit(y, x, weights):
    y = np.asarray(y, dtype=float)
    x_mat = np.asarray(x, dtype=float)
    w = np.asarray(weights, dtype=float)
    w = w / np.mean(w)

    def objective(beta):
        xb = x_mat @ beta
        p = np.clip(norm.cdf(xb), 1e-9, 1 - 1e-9)
        return -np.sum(w * (y * np.log(p) + (1 - y) * np.log(1 - p)))

    def gradient(beta):
        xb = x_mat @ beta
        p = np.clip(norm.cdf(xb), 1e-9, 1 - 1e-9)
        pdf = norm.pdf(xb)
        score_factor = w * pdf * (y - p) / (p * (1 - p))
        return -(x_mat.T @ score_factor)

    result = minimize(
        objective,
        np.zeros(x_mat.shape[1]),
        method="BFGS",
        jac=gradient,
        options={"maxiter": 1000, "gtol": 1e-5},
    )
    if not result.success and not np.isfinite(result.fun):
        raise RuntimeError(result.message)

    beta = result.x
    cov = np.asarray(result.hess_inv)
    se = np.sqrt(np.diag(cov))
    z = beta / se
    p_values = 2 * (1 - norm.cdf(np.abs(z)))
    return pd.DataFrame(
        {
            "term": x.columns,
            "estimate": beta,
            "std_error": se,
            "z_value": z,
            "p_value": p_values,
        }
    ), beta


def predict_probit(x, beta):
    return norm.cdf(np.asarray(x, dtype=float) @ beta)


def average_partial_effects(df, x, beta):
    p_density = norm.pdf(np.asarray(x, dtype=float) @ beta)
    weight = df["weight"].to_numpy()
    log_income_beta = beta[list(x.columns).index("log_income")]
    rows = [
        {
            "variable": "Log income",
            "average_partial_effect": np.average(p_density * log_income_beta, weights=weight),
        }
    ]

    reference = df.copy()
    reference["education"] = "Primary or less"
    x_ref = design_matrix(reference)
    p_ref = predict_probit(x_ref, beta)

    for level in ["Lower secondary", "Upper secondary", "University"]:
        changed = df.copy()
        changed["education"] = level
        x_changed = design_matrix(changed)
        p_changed = predict_probit(x_changed, beta)
        rows.append(
            {
                "variable": f"Education: {level} vs Primary or less",
                "average_partial_effect": np.average(p_changed - p_ref, weights=weight),
            }
        )

    return pd.DataFrame(rows)


def make_prediction_grid(df, beta):
    incomes = np.quantile(df["income"], np.linspace(0.05, 0.95, 19))
    grid = pd.MultiIndex.from_product(
        [incomes, ["Primary or less", "Lower secondary", "Upper secondary", "University"]],
        names=["income", "education"],
    ).to_frame(index=False)
    grid["log_income"] = np.log(grid["income"])
    grid["age_centered"] = np.average(df["age"], weights=df["weight"]) - 55
    grid["age_centered_squared"] = grid["age_centered"] ** 2
    grid["region"] = "North"
    grid["household_size"] = round(np.average(df["household_size"], weights=df["weight"]))
    grid["female_head"] = 0
    grid["predicted_probability"] = predict_probit(design_matrix(grid), beta)
    return grid


def save_figures(df, prediction_grid):
    edu = (
        df.groupby("education", observed=False)
        .apply(lambda g: pd.Series({"participation_rate": np.average(g["stock_participation"], weights=g["weight"])}))
        .reindex(["Primary or less", "Lower secondary", "Upper secondary", "University"])
    )

    fig, ax = plt.subplots(figsize=(7, 4.5))
    ax.bar(edu.index, edu["participation_rate"], color="#2F6F73")
    ax.set_title("Stock Market Participation by Education")
    ax.set_xlabel("Education level")
    ax.set_ylabel("Participation rate")
    ax.yaxis.set_major_formatter(lambda value, pos: f"{value:.0%}")
    plt.xticks(rotation=20, ha="right")
    plt.tight_layout()
    fig.savefig(OUT_DIR / "participation_by_education.png", dpi=300)
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(7, 4.5))
    for education, group in prediction_grid.groupby("education"):
        ax.plot(group["income"], group["predicted_probability"], label=education, linewidth=2)
    ax.set_title("Predicted Probability of Stock Market Participation")
    ax.set_xlabel("Annual household income")
    ax.set_ylabel("Predicted probability")
    ax.yaxis.set_major_formatter(lambda value, pos: f"{value:.0%}")
    ax.xaxis.set_major_formatter(lambda value, pos: f"EUR {value:,.0f}")
    ax.legend(title="Education")
    plt.tight_layout()
    fig.savefig(OUT_DIR / "predicted_probability_by_income_education.png", dpi=300)
    plt.close(fig)


def main():
    df = build_dataset()
    df.to_csv(OUT_DIR / "analysis_dataset.csv", index=False)

    overall = pd.DataFrame(
        [
            {
                "households": len(df),
                "weighted_participation_rate": np.average(df["stock_participation"], weights=df["weight"]),
                "median_income": df["income"].median(),
                "mean_age": np.average(df["age"], weights=df["weight"]),
            }
        ]
    )
    overall.to_csv(OUT_DIR / "summary_overall.csv", index=False)

    by_education = (
        df.groupby("education", observed=False)
        .apply(
            lambda g: pd.Series(
                {
                    "households": len(g),
                    "weighted_participation_rate": np.average(g["stock_participation"], weights=g["weight"]),
                    "median_income": g["income"].median(),
                }
            )
        )
        .reset_index()
    )
    by_education.to_csv(OUT_DIR / "summary_by_education.csv", index=False)

    by_region = (
        df.groupby("region", observed=False)
        .apply(
            lambda g: pd.Series(
                {
                    "households": len(g),
                    "weighted_participation_rate": np.average(g["stock_participation"], weights=g["weight"]),
                    "median_income": g["income"].median(),
                }
            )
        )
        .reset_index()
    )
    by_region.to_csv(OUT_DIR / "summary_by_region.csv", index=False)

    x = design_matrix(df)
    models = {}
    betas = {}
    for outcome in ["stock_participation", "mutual_fund_or_etf", "direct_listed_stock"]:
        table, beta = fit_weighted_probit(df[outcome], x, df["weight"])
        table.insert(0, "outcome", outcome)
        models[outcome] = table
        betas[outcome] = beta

    results = pd.concat(models.values(), ignore_index=True)
    results.to_csv(OUT_DIR / "probit_results.csv", index=False)
    results.to_html(OUT_DIR / "probit_results.html", index=False, float_format="{:.4f}".format)

    ape = average_partial_effects(df, x, betas["stock_participation"])
    ape.to_csv(OUT_DIR / "average_partial_effects.csv", index=False)

    prediction_grid = make_prediction_grid(df, betas["stock_participation"])
    prediction_grid.to_csv(OUT_DIR / "predicted_probabilities.csv", index=False)
    save_figures(df, prediction_grid)

    print("Analysis complete.")
    print(f"Households used: {len(df):,}")
    print(f"Weighted participation rate: {overall.loc[0, 'weighted_participation_rate']:.2%}")
    print(f"Outputs saved in: {OUT_DIR}")


if __name__ == "__main__":
    main()

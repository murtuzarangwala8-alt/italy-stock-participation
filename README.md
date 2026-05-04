# Household Stock Market Participation in Italy

> **Do income and education predict whether Italian households invest in stocks or mutual funds?**  
> Empirical analysis using the 2022 Bank of Italy SHIW micro-dataset.

---

## Overview

This project estimates a survey-weighted **probit model** to study the socioeconomic determinants of stock market participation among Italian households. The analysis uses the **Survey on Household Income and Wealth (SHIW 2022)** published by the Bank of Italy.

### Key Findings

| Metric | Value |
|---|---|
| Households in sample | 9,617 |
| Weighted participation rate | **12.0%** |
| APE of log income | **+12.5 pp** |
| APE of university vs primary education | **+13.6 pp** |
| Participation — North vs South | **18.4% vs 2.3%** |

Both income and education are positive and statistically significant predictors of participation, even after controlling for age, household size, gender, and region.

---

## Interactive Presentation

Open **`presentation.html`** in any browser for a full visual summary — no server required.

It includes:
- Key statistics hero section
- Bar charts by education level and region
- Average partial effects with animated bars
- Full probit results table (3 models)
- Grouped coefficient comparison chart

---

## Repository Structure

```
├── analysis_stock_participation.R     # Main R analysis script (survey-weighted probit)
├── analysis_stock_participation.py    # Python equivalent
├── shiw_stata_quick_analysis.do       # Optional Stata version
├── validate_shiw_data.py              # Data validation checks
├── print_project_results.R            # Print formatted results to console
├── print_project_results.py           # Python version of above
├── project_proposal.tex               # Original LaTeX project proposal
├── results_writeup.tex                # LaTeX results write-up
├── presentation.html                  # ← Interactive front-end presentation
└── output/
    ├── probit_results.csv             # Regression coefficients (all 3 models)
    ├── average_partial_effects.csv    # APEs for main model
    ├── summary_by_education.csv       # Participation & income by education
    ├── summary_by_region.csv          # Participation & income by region
    ├── summary_overall.csv            # Overall sample statistics
    ├── predicted_probabilities.csv    # Predicted Pr(participation) per household
    ├── participation_by_education.png # Figure 1
    ├── predicted_probability_by_income_education.png  # Figure 2
    ├── probit_results.html            # Formatted regression table
    └── validation_report.csv         # Data quality checks
```

---

## Econometric Model

```
Pr(stock_participation = 1) = Φ(β₀ + β₁ log(income) + β₂ education + γ Z)
```

where `Z` includes age, age², household size, gender of head, and geographic region.  
Three outcome variables are estimated: `stock_participation`, `mutual_fund_or_etf`, `direct_listed_stock`.

---

## How to Run

### R (recommended)

```r
source("analysis_stock_participation.R")
```

Requires the `survey`, `haven`, and `dplyr` packages.

### Python

```powershell
python analysis_stock_participation.py
```

### Stata

Open and run `shiw_stata_quick_analysis.do` in Stata 16+.

---

## Data

The analysis uses four SHIW 2022 Stata files:

| File | Contents used |
|---|---|
| `carcom22.dta` | Age, education, gender, region of household head |
| `rfam22.dta` | Household income (`Y`) |
| `q22c2.dta` | Financial asset ownership (stocks, funds, ETFs) |
| `q22a.dta` | Household size and survey weight |

> **Note:** The raw SHIW data is not included in this repository. Download it from the [Bank of Italy website](https://www.bancaditalia.it/statistiche/tematiche/indagini-famiglie-imprese/bilanci-famiglie/index.html) and update `DATA_DIR` in the R script.

The dependent variable `stock_participation = 1` if the household holds any of:
`POS_D3` (mutual funds), `POS_D4` (ETFs), `POS_E1` (listed shares), `POS_E2` (unlisted shares), `POS_F2` (foreign securities).

---

## References

- Guiso, L., Haliassos, M., & Jappelli, T. (2003). *Household Stockholding in Europe: Where Do We Stand and Where Do We Go?*
- Guiso, L., Sapienza, P., & Zingales, L. (2008). Trusting the stock market. *Journal of Finance*, 63(6), 2557–2600.
- Campbell, J. Y. (2006). Household finance. *Journal of Finance*, 61(4), 1553–1604.
- Bank of Italy. *Survey on Household Income and Wealth (SHIW)*.

---

## Author

**Murtaza** · [github.com/murtuzarangwala8-alt](https://github.com/murtuzarangwala8-alt)

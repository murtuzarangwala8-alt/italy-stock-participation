# Determinants of Household Stock Market Participation in Italy
# Author: Murtaza
#
# This script estimates whether income and education predict household
# participation in risky financial assets, using a probit model.
#
# How to use:
# 1. Run as-is for a complete demo using simulated SHIW-like data.
# 2. When you have the Bank of Italy SHIW dataset, set USE_REAL_DATA <- TRUE
#    and update the CONFIG section below with your file path and variable names.

rm(list = ls())

required_packages <- c(
  "tidyverse",
  "haven",
  "survey",
  "broom",
  "modelsummary",
  "scales"
)

install_if_missing <- function(packages) {
  missing <- packages[!packages %in% rownames(installed.packages())]
  if (length(missing) > 0) {
    install.packages(missing, dependencies = TRUE)
  }
}

install_if_missing(required_packages)

library(tidyverse)
library(haven)
library(survey)
library(broom)
library(modelsummary)
library(scales)

# -------------------------------------------------------------------------
# CONFIG
# -------------------------------------------------------------------------

USE_REAL_DATA <- TRUE

# Folder containing the Bank of Italy SHIW 2022 Stata files.
DATA_DIR <- "C:/Users/murta/Desktop/local pro/ind22_stata/STATA"

output_dir <- "output"
dir.create(output_dir, showWarnings = FALSE)

# -------------------------------------------------------------------------
# DATA LOADING
# -------------------------------------------------------------------------

simulate_shiw_like_data <- function(n = 7000, seed = 123) {
  set.seed(seed)

  education_levels <- c(
    "Primary or less",
    "Lower secondary",
    "Upper secondary",
    "University"
  )

  tibble(
    household_id = seq_len(n),
    income = exp(rnorm(n, log(33000), 0.75)),
    education = sample(
      education_levels,
      n,
      replace = TRUE,
      prob = c(0.18, 0.28, 0.38, 0.16)
    ),
    age = round(pmin(pmax(rnorm(n, 55, 15), 18), 90)),
    region = sample(
      c("North", "Centre", "South and Islands"),
      n,
      replace = TRUE,
      prob = c(0.46, 0.20, 0.34)
    ),
    household_size = sample(1:5, n, replace = TRUE, prob = c(0.28, 0.32, 0.22, 0.13, 0.05)),
    weight = runif(n, 0.4, 2.2)
  ) |>
    mutate(
      education_score = case_when(
        education == "Primary or less" ~ 0,
        education == "Lower secondary" ~ 1,
        education == "Upper secondary" ~ 2,
        education == "University" ~ 3
      ),
      latent_participation =
        -3.25 +
        0.55 * log(income / 10000) +
        0.33 * education_score +
        0.015 * age -
        0.00018 * (age - 55)^2 -
        0.18 * (region == "South and Islands") +
        0.08 * (region == "North") -
        0.04 * household_size +
        rnorm(n),
      participates = as.integer(latent_participation > 0),
      stock_or_fund_value = if_else(
        participates == 1,
        round(exp(rnorm(n, log(18000), 1.0)), 0),
        0
      )
    ) |>
    select(-education_score, -latent_participation, -participates)
}

load_shiw_2022 <- function(data_dir) {
  q22a <- read_dta(file.path(data_dir, "q22a.dta")) |>
    rename_with(tolower) |>
    transmute(
      nquest,
      household_size = as.numeric(ncomp),
      weight = as.numeric(pesofit)
    )

  income <- read_dta(file.path(data_dir, "rfam22.dta")) |>
    rename_with(tolower) |>
    transmute(
      nquest,
      income = as.numeric(y)
    )

  assets <- read_dta(file.path(data_dir, "q22c2.dta")) |>
    rename_with(tolower) |>
    transmute(
      nquest,
      mutual_funds = as.integer(pos_d3 == 1),
      etf = as.integer(pos_d4 == 1),
      listed_shares = as.integer(pos_e1 == 1),
      unlisted_shares = as.integer(pos_e2 == 1),
      foreign_securities = as.integer(pos_f2 == 1),
      managed_savings = as.integer(pos_b == 1),
      stock_participation = as.integer(
        pos_d3 == 1 |
          pos_d4 == 1 |
          pos_e1 == 1 |
          pos_e2 == 1 |
          pos_f2 == 1
      ),
      direct_listed_stock = as.integer(pos_e1 == 1),
      mutual_fund_or_etf = as.integer(pos_d3 == 1 | pos_d4 == 1)
    )

  household_head <- read_dta(file.path(data_dir, "carcom22.dta")) |>
    rename_with(tolower) |>
    filter(parent == 1) |>
    transmute(
      nquest,
      age = as.numeric(eta),
      education_raw = as.numeric(studio),
      region_raw = as.numeric(ireg),
      area3_raw = as.numeric(area3),
      female_head = as.integer(sex == 2),
      education = case_when(
        education_raw %in% c(1, 2) ~ "Primary or less",
        education_raw == 3 ~ "Lower secondary",
        education_raw %in% c(4, 5, 6) ~ "Upper secondary",
        education_raw %in% c(7, 8) ~ "University",
        TRUE ~ NA_character_
      ),
      region = case_when(
        area3_raw == 1 ~ "North",
        area3_raw == 2 ~ "Centre",
        area3_raw == 3 ~ "South and Islands",
        TRUE ~ NA_character_
      )
    )

  q22a |>
    left_join(income, by = "nquest") |>
    left_join(assets, by = "nquest") |>
    left_join(household_head, by = "nquest")
}

raw_data <- if (USE_REAL_DATA) {
  load_shiw_2022(DATA_DIR)
} else {
  message("USE_REAL_DATA is FALSE: running demo with simulated SHIW-like data.")
  simulate_shiw_like_data()
}

# -------------------------------------------------------------------------
# VARIABLE CONSTRUCTION
# -------------------------------------------------------------------------

analysis_data <- raw_data |>
  transmute(
    stock_participation = as.integer(stock_participation),
    direct_listed_stock = as.integer(direct_listed_stock),
    mutual_fund_or_etf = as.integer(mutual_fund_or_etf),
    income = as.numeric(income),
    log_income = log(income),
    education = as.factor(education),
    age = as.numeric(age),
    age_centered = age - 55,
    age_centered_squared = age_centered^2,
    region = as.factor(region),
    household_size = as.numeric(household_size),
    female_head = as.integer(female_head),
    weight = as.numeric(weight)
  ) |>
  filter(
    !is.na(stock_participation),
    !is.na(income),
    income > 0,
    !is.na(education),
    !is.na(age),
    !is.na(region),
    !is.na(household_size),
    !is.na(female_head),
    !is.na(weight),
    weight > 0
  )

analysis_data <- analysis_data |>
  mutate(
    education = forcats::fct_relevel(
      education,
      "Primary or less",
      "Lower secondary",
      "Upper secondary",
      "University"
    ),
    region = forcats::fct_relevel(region, "North")
  )

write_csv(analysis_data, file.path(output_dir, "analysis_dataset.csv"))

# -------------------------------------------------------------------------
# DESCRIPTIVE STATISTICS
# -------------------------------------------------------------------------

participation_rate <- analysis_data |>
  summarise(
    households = n(),
    participation_rate = mean(stock_participation),
    median_income = median(income),
    mean_age = mean(age)
  )

participation_by_education <- analysis_data |>
  group_by(education) |>
  summarise(
    households = n(),
    participation_rate = mean(stock_participation),
    median_income = median(income),
    .groups = "drop"
  )

participation_by_region <- analysis_data |>
  group_by(region) |>
  summarise(
    households = n(),
    participation_rate = mean(stock_participation),
    median_income = median(income),
    .groups = "drop"
  )

write_csv(participation_rate, file.path(output_dir, "summary_overall.csv"))
write_csv(participation_by_education, file.path(output_dir, "summary_by_education.csv"))
write_csv(participation_by_region, file.path(output_dir, "summary_by_region.csv"))

# -------------------------------------------------------------------------
# SURVEY DESIGN AND PROBIT MODELS
# -------------------------------------------------------------------------

options(survey.lonely.psu = "adjust")

design <- svydesign(
  ids = ~1,
  weights = ~weight,
  data = analysis_data
)

model_1 <- svyglm(
  stock_participation ~ log_income + education,
  design = design,
  family = quasibinomial(link = "probit")
)

model_2 <- svyglm(
  stock_participation ~ log_income + education + age_centered + age_centered_squared +
    region + household_size + female_head,
  design = design,
  family = quasibinomial(link = "probit")
)

model_3 <- svyglm(
  mutual_fund_or_etf ~ log_income + education + age_centered + age_centered_squared +
    region + household_size + female_head,
  design = design,
  family = quasibinomial(link = "probit")
)

model_4 <- svyglm(
  direct_listed_stock ~ log_income + education + age_centered + age_centered_squared +
    region + household_size + female_head,
  design = design,
  family = quasibinomial(link = "probit")
)

modelsummary(
  list(
    "Baseline probit" = model_1,
    "Controls probit" = model_2,
    "Funds/ETF only" = model_3,
    "Listed stocks only" = model_4
  ),
  stars = TRUE,
  statistic = "std.error",
  output = file.path(output_dir, "probit_results.html")
)

modelsummary(
  list(
    "Baseline probit" = model_1,
    "Controls probit" = model_2,
    "Funds/ETF only" = model_3,
    "Listed stocks only" = model_4
  ),
  stars = TRUE,
  statistic = "std.error",
  output = file.path(output_dir, "probit_results.tex")
)

# -------------------------------------------------------------------------
# AVERAGE PARTIAL EFFECTS
# -------------------------------------------------------------------------

average_partial_effect_log_income <- function(model, data) {
  eta <- predict(model, type = "link")
  beta <- coef(model)[["log_income"]]
  tibble(
    variable = "Log income",
    average_partial_effect = weighted.mean(dnorm(eta) * beta, data$weight)
  )
}

discrete_effect <- function(model, data, variable, level, reference_level) {
  data_reference <- data
  data_level <- data

  data_reference[[variable]] <- factor(
    reference_level,
    levels = levels(data[[variable]])
  )
  data_level[[variable]] <- factor(
    level,
    levels = levels(data[[variable]])
  )

  p_reference <- predict(model, newdata = data_reference, type = "response")
  p_level <- predict(model, newdata = data_level, type = "response")

  tibble(
    variable = paste0(variable, ": ", level, " vs ", reference_level),
    average_partial_effect = weighted.mean(p_level - p_reference, data$weight)
  )
}

income_ape <- average_partial_effect_log_income(model_2, analysis_data)

education_reference <- levels(analysis_data$education)[1]
education_apes <- map_dfr(
  levels(analysis_data$education)[-1],
  ~ discrete_effect(model_2, analysis_data, "education", .x, education_reference)
)

average_partial_effects <- bind_rows(income_ape, education_apes)
write_csv(average_partial_effects, file.path(output_dir, "average_partial_effects.csv"))

# -------------------------------------------------------------------------
# PREDICTED PROBABILITIES
# -------------------------------------------------------------------------

income_grid <- tibble(
  income = quantile(analysis_data$income, probs = seq(0.05, 0.95, by = 0.05)),
  log_income = log(income)
)

prediction_grid <- expand_grid(
  income_grid,
  education = levels(analysis_data$education)
) |>
  mutate(
    age_centered = weighted.mean(analysis_data$age, analysis_data$weight) - 55,
    age_centered_squared = age_centered^2,
    region = "North",
    household_size = round(weighted.mean(analysis_data$household_size, analysis_data$weight)),
    female_head = 0
  ) |>
  mutate(
    education = factor(education, levels = levels(analysis_data$education)),
    region = factor(region, levels = levels(analysis_data$region))
  )

prediction_grid$predicted_probability <- as.numeric(
  predict(model_2, newdata = prediction_grid, type = "response")
)

write_csv(prediction_grid, file.path(output_dir, "predicted_probabilities.csv"))

# -------------------------------------------------------------------------
# FIGURES
# -------------------------------------------------------------------------

plot_education <- participation_by_education |>
  ggplot(aes(x = education, y = participation_rate)) +
  geom_col(fill = "#2F6F73", width = 0.65) +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  labs(
    title = "Stock Market Participation by Education",
    x = "Education level",
    y = "Participation rate"
  ) +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))

ggsave(
  file.path(output_dir, "participation_by_education.png"),
  plot_education,
  width = 7,
  height = 4.5,
  dpi = 300
)

plot_predictions <- prediction_grid |>
  ggplot(aes(x = income, y = predicted_probability, color = education)) +
  geom_line(linewidth = 1) +
  scale_x_continuous(labels = label_number(prefix = "EUR ", big.mark = ",")) +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  labs(
    title = "Predicted Probability of Stock Market Participation",
    x = "Annual household income",
    y = "Predicted probability",
    color = "Education"
  ) +
  theme_minimal(base_size = 12)

ggsave(
  file.path(output_dir, "predicted_probability_by_income_education.png"),
  plot_predictions,
  width = 7,
  height = 4.5,
  dpi = 300
)

# -------------------------------------------------------------------------
# CONSOLE SUMMARY
# -------------------------------------------------------------------------

cat("\nAnalysis complete.\n")
cat("Main output folder:", normalizePath(output_dir), "\n\n")

print(participation_rate)
print(participation_by_education)
print(average_partial_effects)

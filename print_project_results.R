# Print the main results and a short summary of the SHIW stock participation code.
#
# Run this after analysis_stock_participation.R.

output_dir <- "C:/Users/murta/Documents/Codex/2026-05-04/documentclass-12pt-article-usepackage-utf8-inputenc/output"

pct <- function(x) {
  sprintf("%.2f%%", 100 * x)
}

read_output <- function(filename) {
  read.csv(file.path(output_dir, filename), stringsAsFactors = FALSE)
}

overall <- read_output("summary_overall.csv")
by_education <- read_output("summary_by_education.csv")
by_region <- read_output("summary_by_region.csv")
ape <- read_output("average_partial_effects.csv")
results <- read_output("probit_results.csv")

main_model <- subset(results, outcome == "stock_participation")
important_terms <- c(
  "log_income",
  "education_Lower secondary",
  "education_Upper secondary",
  "education_University",
  "region_Centre",
  "region_South and Islands",
  "household_size",
  "female_head"
)
main_model <- main_model[main_model$term %in% important_terms, ]

cat("\n")
cat("========================================================================\n")
cat("PROJECT RESULTS: HOUSEHOLD STOCK MARKET PARTICIPATION IN ITALY\n")
cat("========================================================================\n")

cat("\n1. Overall Sample\n")
cat("Households used:", format(overall$households[1], big.mark = ","), "\n")
cat("Weighted stock market participation rate:", pct(overall$weighted_participation_rate[1]), "\n")
cat("Median household income: EUR", format(round(overall$median_income[1]), big.mark = ","), "\n")
cat("Weighted mean age of household head:", round(overall$mean_age[1], 1), "\n")

cat("\n2. Participation by Education\n")
by_education <- by_education[order(by_education$weighted_participation_rate), ]
for (i in seq_len(nrow(by_education))) {
  cat(
    by_education$education[i], ": ",
    pct(by_education$weighted_participation_rate[i]),
    ", median income EUR ",
    format(round(by_education$median_income[i]), big.mark = ","),
    "\n",
    sep = ""
  )
}

cat("\n3. Participation by Region\n")
by_region <- by_region[order(-by_region$weighted_participation_rate), ]
for (i in seq_len(nrow(by_region))) {
  cat(
    by_region$region[i], ": ",
    pct(by_region$weighted_participation_rate[i]),
    ", median income EUR ",
    format(round(by_region$median_income[i]), big.mark = ","),
    "\n",
    sep = ""
  )
}

cat("\n4. Main Probit Model Coefficients\n")
cat("Positive coefficient means higher probability of participation.\n")
for (i in seq_len(nrow(main_model))) {
  p_value <- main_model$p_value[i]
  stars <- ifelse(
    p_value < 0.01, "***",
    ifelse(p_value < 0.05, "**", ifelse(p_value < 0.10, "*", ""))
  )
  cat(
    main_model$term[i], ": ",
    "coef = ", sprintf("%.4f", main_model$estimate[i]),
    ", std. error = ", sprintf("%.4f", main_model$std_error[i]),
    ", p-value = ", format(p_value, scientific = TRUE, digits = 4),
    " ", stars,
    "\n",
    sep = ""
  )
}

cat("\n5. Average Partial Effects\n")
cat("These are easier to interpret than probit coefficients.\n")
for (i in seq_len(nrow(ape))) {
  cat(ape$variable[i], ": ", pct(ape$average_partial_effect[i]), "\n", sep = "")
}

cat("\n6. Short Interpretation\n")
cat(
  "The results support the hypothesis: higher income and higher education ",
  "are both associated with a higher probability of owning stocks, mutual ",
  "funds, ETFs, or similar financial assets.\n",
  sep = ""
)
cat(
  "University-educated households have a much higher predicted participation ",
  "probability than households with primary education or less. Participation ",
  "is also lower in the South and Islands compared with the North.\n",
  sep = ""
)

cat("\n7. Summary of What the Code Does\n")
cat("Step 1: Reads SHIW 2022 Stata files from your data folder.\n")
cat("Step 2: Merges household, income, asset, and demographic files by nquest.\n")
cat("Step 3: Creates stock_participation from POS_D3, POS_D4, POS_E1, POS_E2, and POS_F2.\n")
cat("Step 4: Cleans missing or invalid observations.\n")
cat("Step 5: Estimates weighted probit models.\n")
cat("Step 6: Exports tables, marginal effects, validation checks, and graphs.\n")

cat("\nOutput folder:\n")
cat(output_dir, "\n")
cat("========================================================================\n\n")


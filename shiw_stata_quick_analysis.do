* Determinants of Household Stock Market Participation in Italy
* Quick Stata version using SHIW 2022 files

clear all
set more off

global data "C:\Users\murta\Desktop\local pro\ind22_stata\STATA"
global out "C:\Users\murta\Documents\Codex\2026-05-04\documentclass-12pt-article-usepackage-utf8-inputenc\output"

cap mkdir "$out"

use "$data\q22a.dta", clear
keep nquest ncomp pesofit
rename ncomp household_size
rename pesofit weight

merge 1:1 nquest using "$data\rfam22.dta", keepusing(y) nogen
rename y income

merge 1:1 nquest using "$data\q22c2.dta", keepusing(pos_d3 pos_d4 pos_e1 pos_e2 pos_f2) nogen
gen stock_participation = (pos_d3 == 1 | pos_d4 == 1 | pos_e1 == 1 | pos_e2 == 1 | pos_f2 == 1)
gen mutual_fund_or_etf = (pos_d3 == 1 | pos_d4 == 1)
gen direct_listed_stock = (pos_e1 == 1)

preserve
use "$data\carcom22.dta", clear
keep if parent == 1
keep nquest eta studio area3 sex
rename eta age
gen female_head = (sex == 2)

gen education = .
replace education = 1 if inlist(studio, 1, 2)
replace education = 2 if studio == 3
replace education = 3 if inlist(studio, 4, 5, 6)
replace education = 4 if inlist(studio, 7, 8)
label define education_lab 1 "Primary or less" 2 "Lower secondary" 3 "Upper secondary" 4 "University"
label values education education_lab

gen region = area3
label define region_lab 1 "North" 2 "Centre" 3 "South and Islands"
label values region region_lab

tempfile head
save `head'
restore

merge 1:1 nquest using `head', nogen

drop if missing(stock_participation, income, education, age, region, household_size, female_head, weight)
drop if income <= 0 | weight <= 0

gen log_income = log(income)
gen age_centered = age - 55
gen age_centered_squared = age_centered^2

save "$out\analysis_dataset.dta", replace

tab stock_participation
tab education stock_participation, row
tab region stock_participation, row

probit stock_participation log_income i.education age_centered age_centered_squared i.region household_size female_head [pweight=weight], vce(robust)
margins, dydx(log_income i.education)
margins education, at(log_income=(9(0.25)12))

probit mutual_fund_or_etf log_income i.education age_centered age_centered_squared i.region household_size female_head [pweight=weight], vce(robust)
probit direct_listed_stock log_income i.education age_centered age_centered_squared i.region household_size female_head [pweight=weight], vce(robust)

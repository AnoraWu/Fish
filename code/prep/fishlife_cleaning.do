/*
FishLife Cleaning

Purpose: Prepares the data optained from James Thorson's R Package FishLife for use in Stata.

Author: Matthew Neils

Date: 4/1/2024
*/

import delimited "data/raw/fishlife.csv", clear 

*Formatting names to be compatable with RAM data
gen full_scientificname = subinstr(v1,"_"," ",.)
drop v1

*Labeling variables*
rename loo ln_loo
rename winfinity ln_winfinity

label var ln_loo "Asymptotic length"
label var k "Von Bertalanffy K"
label var ln_winfinity "Asymptotic mass"
label var tmax "Maximum age"
label var tm "Age at maturity"
label var m "Mortality rate"
label var lm "Length at maturity"
label var temperature "Average temperature"
label var ln_var "Conditional recruitment variance"
label var rho "Recruitment autocorrelation"
label var ln_masps "Maximum annual spawners per spawner"
label var ln_margsd "SD of recruitment"
label var h "Steepness"
label var logitbound_h "Steepness"
label var ln_fmsy_over_m "Ratio of F_msy and M"
label var ln_fmsy "Fishing mortality rate at MSY"
label var ln_r "Intrinsic growth rate"
label var ln_g "Generation Time"
label var r "Intrinsic growth rate"
label var g "Generation Time"

*Generating a variable to flag results that are predicted and dropping from names*
gen predicted = (strpos(full_scientificname, "predictive") != 0)
label var predicted "Results were predicted (Thorson (2017))"

replace full_scientificname = subinstr(full_scientificname,"predictive","",.)
replace full_scientificname = strrtrim(full_scientificname)

duplicates report full_scientificname

*For now, we want to only look at fish with data in fishbase, rather than using predictive results*
drop if predicted == 1

*Generating a shortened scientific name that can be matched with other datasets. There are entries from the class level downward, so only observations with the class through the species will identify species in a matchable way. Thus, we only generate short names for observations that have five words in the name*
gen scientificname = word(full_scientificname,-2) + " " + word(full_scientificname,-1) if wordcount(full_scientificname) == 5

*For shorter full scientific names (i.e. not at the species level) we can just bring over the last name, which is the most specific identifier. This may be useful for providing info on species that do not have a direct match in this dataset*
replace scientificname = word(full_scientificname,-1) if scientificname == ""

save "data/intermediate/life_history.dta", replace

/*
FAO Cleaning

Purpose: Attach MPA and location information to FAO data and prepare for ML predicitons

Author: Matthew Neils

Date: 4/22/2024
*/

use "data/intermediate/FAO_country_long_GLOBAL.dta", clear

*Attaching MPA information*
preserve
tempfile MPAS
import delimited "data/intermediate/FAO_rhos.csv", varnames(1) clear
keep stockid rho*
local mpanum = 175
forva i = 1/`mpanum'{
	gen mpa`i' = (rho_mpa_`i' > 0)
}
save `MPAS'
restore

merge m:1 stockid using `MPAS'

preserve
unique stockid if _merge == 1
bysort _merge: egen sumlandings = sum(landings)
sum sumlandings if _merge == 1
local nomaps = r(mean)
sum sumlandings if _merge == 3
local maps = r(mean)
di `nomaps'/(`nomaps' + `maps')
*3835 stocks have no maps, but these are only 14.5% of total landings.*
restore

keep if _merge == 3
drop _merge

*Keeping only catch series of at least 25 years and only looking at stocks after their 20th year.*
egen num_years = count(landings), by(stockid)
drop if num_years < 25

*Dropping 

*Renaming variables*
rename scaled_landings c_div_maxc
rename max_harvest_ratio c_roll_maxc
rename age fishery_year

*Generating landings scaled by mean landings in the fishery*
gen c_div_meanc = landings/m_landings

*Generating mortality divided by Von Bertalanffy growth coefficient*
gen m_v_k = exp(m)/exp(k)

*Generating Von Bertalanffy asymptotic length divided by length at maturity*
gen linf_v_lmat = exp(ln_loo)/exp(lm)

*Mean landings before this year
gen mean_yet = .
forva i = 0/70{
	
	egen mean_yet_`i' = mean(landings) if fishery_year < `i', by(english_name stocklevel faoarea)
	egen mean_yet_all_`i' = mean(mean_yet_`i'), by(english_name stocklevel faoarea)
	replace mean_yet = mean_yet_all_`i' if fishery_year == `i'
	drop mean_yet*_`i'
	
}
label var mean_yet "Mean landings before this year"

gen c_roll_meanc = landings/mean_yet
replace c_roll_meanc = 1 if fishery_year == 0
label var c_roll_meanc "Ratio of harvest to running mean"

*Generating metric tag*
gen metric = "b_v_bmsy"

*Bringing in an FAO areaname to number crosswalk*
preserve
tempfile FAONUMs
import delimited "data/intermediate/FAO_Crosswalk.csv", varnames(1) clear
keep f_code name_en
rename name_en faoarea
rename f_code fao_area_code
save `FAONUMs', replace
restore

merge m:1 faoarea using `FAONUMs', nogen

*Keeping info necessary for Ovando ML*

keep stockid isscaap scientificname landings year num_years c_div_maxc c_div_meanc c_roll_maxc c_roll_meanc metric fishery_year fao_area_code ln_loo k ln_winfinity tmax tm m lm temperature ln_var rho ln_masps ln_margsd h logitbound_h ln_fmsy_over_m ln_fmsy ln_r r ln_g g m_v_k linf_v_lmat english_name stocklevel faoarea scientificname mpa* rho*

save "data/intermediate/FAO_Pred_Prep_GLOBAL.dta", replace

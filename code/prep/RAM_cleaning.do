/*
RAM Cleaning 

Purpose: Prepares the biological and economic data obtained from the RAM Database

Author: Matthew Neils

Date: 4/1/2024
*/

/*------------------------------------------------------------------------------
Data Import
------------------------------------------------------------------------------*/

*Bringing in Parameter Data*
import excel "data/raw/RAMLDB v4/Excel/RAMLDB v4.495 (assessment data only).xlsx", sheet("bioparams_values_views") firstrow clear

*Labeling Variables*
{
	local labels `" "Stock ID" "Stock name" "General total biomass at MSY" "General exploitation rate at MSY" "General total biomass at MT" "General exploitation rate at MT" "Total biomass corresponding to MSY" "Spawning stock biomass corresponding to MSY" "Total abundance corresponding to MSY" "Maximum sustainable yield" "Fishing mortality corresponding to MSY" "Exploitation rate corresponding to MSY" "Total biomass MT" "Spawning stock biomass MT" "Fishing mortality MT" "Exploitation rate MT" "Pre-exploitation total biomass" "Pre-exploitation spawning stock biomass" "Natural mortality" "Total biomass lower ML" "Spawning stock biomass lower ML" "Fishing mortality ML" "Exploitation rate ML" "'
}
{
	local names `" "stockid" "stocklong" "TBmsybest" "ERmsybest" "TBmgtbest" "ERmgtbest" "TBmsy" "SSBmsy" "Nmsy" "MSY" "Fmsy" "ERmsy" "TBmgt" "SSBmgt" "Fmgt" "ERmgt" "TB0" "SSB0" "M" "TBlim" "SSBlim" "Flim" "ERlim" "'	
}

local N: word count `labels'
di `N'

forvalues i = 1/`N'{
	local label: word `i' of `labels'
	local var: word `i' of `names'
	label variable `var' "`label'"
}

save "data/intermediate/RAM_param.dta", replace

*Bringing in Time-Series Data*
import excel "data/raw/RAMLDB v4/Excel/RAMLDB v4.495 (assessment data only).xlsx", sheet(timeseries_values_views) firstrow clear

*Labeling Variables
{
local names `" "stockid" "stocklong" "TBbest" "TCbest" "ERbest" "BdivBmsypref" "UdivUmsypref" "BdivBmgtpref" "UdivUmgtpref" "TB" "SSB" "TN" "R" "TC" "TL" "RecC" "F" "ER" "TBdivTBmsy" "SSBdivSSBmsy" "FdivFmsy" "ERdivERmsy" "TBdivTBmgt" "SSBdivSSBmgt" "FdivFmgt" "ERdivERmgt" "Cpair" "TAC" "Cadvised" "survB" "CPUE" "EFFORT" "'	
}
{	
local labels	`" "Stock ID" "Stock name" "General total biomass time series" "General total catch" "General exploitation rate time series" "General biomass time series" "General harvest rate time series" "General biomass time series" "General harvest rate time series" "Total biomass" "Spawning stock biomass" "Total number" "Recruits" "Total catch" "Total landings" "Recreational catch" "Fishing mortality" "Exploitation rate" "Total biomass relative to TBmsy" "Spawning stock biomass relative to SSBmsy" "Fishing mortality relative to Fmsy" "Exploitation rate relative to ERmsy" "Total biomass relative to TB management target" "Spawning stock biomass relative to SSB management target" "Fishing mortality relative to F management target" "Exploitation rate relative to ER management target" "Catch or landings that is paired with TAC and or Cadvised" "Total allowable catch" "Scientific advice for catch limit" "Survey biomass" "Catch per unit effort" "Fishing effort" "'
}

local N: word count `labels'
di `N'

forvalues i = 1/`N'{
	local label: word `i' of `labels'
	local var: word `i' of `names'
	label variable `var' "`label'"
}

*Bringing in Units*
preserve
tempfile UNITS
import excel "data/raw/RAMLDB v4/Excel/RAMLDB v4.495 (assessment data only).xlsx", sheet(timeseries_units_views) firstrow clear

drop stocklong

rename * UNIT_*
rename UNIT_stockid stockid

save "`UNITS'", replace
restore

merge m:1 stockid using "`UNITS'", nogen keep(match)

tab UNIT_BdivBmsypref
tab UNIT_UdivUmsypref

*Dropping stocks with unrealistic biomass or extraction levels, following Ovando et al. 2021*
drop if BdivBmsypref >= 5
drop if UdivUmsypref >= 10

*Dropping stocks that are too early*
drop if year < 1950

*Keeping only stocks that have more than 25 years of data*
egen num_years = count(year), by(stockid)

*69 stocks have too few years of data*

drop if num_years < 25

sort stockid year
order stockid year

gen year_gap = .
local num = _N
forva i = 2/`num'{
	
	replace year_gap = year[`i']-year[`i'-1] if _n == `i'
	
}

*Positive year gaps greater than 1 indicate that there is a jump in years within an observation. There are 28 stocks where this occurs. We can drop those stocks for now.*
egen noncont = max(year_gap), by(stockid)
drop if noncont > 1
drop year_gap noncont

*Dropping obs before first catch*
egen first_catch_year = min(year) if TCbest > 0, by(stockid)
drop if year < first_catch_year

save "data/intermediate/RAM_timeseries.dta", replace

*Merging Parameters and Timeseries*
merge m:1 stockid using "data/intermediate/RAM_param.dta", keep(match) nogen

*There are 329 stocks with sufficient data at this stage*
*Calculating parameters following the methodology of Costello et al. (2016)
gen growth = MSY/TBmsybest
label var growth "MSY/Bmsy"

*Dropping stocks with MSY > Bmsy (only 4 stocks)
drop if TBmsybest < MSYbest

*Scaling parameter taken from Costello et al. (2016)
gen scaling = 0.188
label var scaling "Scaling Parameter"

*Generating ratios for use in the model*
gen l_TB = log(TBbest)
gen b_ratio = BdivBmsypref
gen f_ratio = UdivUmsypref
label var l_TB "Logged Total Biomass"
label var b_ratio  "Biomass as a proportion of MSY Biomass"
label var f_ratio "Fatality as a proportion of MSY Fatality"

scalar define mpa_reduction = 0.115
scalar define elas_f_effort = 1
gen f_ratio_mpa = f_ratio*(1-((mpa_reduction)*elas_f_effort))
label var f_ratio_mpa "MPA-reduced Fatality as a proportion of MSY Fatality"

save "data/intermediate/RAM_merged.dta", replace

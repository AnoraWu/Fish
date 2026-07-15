/*
RAM Overlaps

Purpose: Brings in the spatial overlap information to filter out RAM stocks and get stock-specific rhos

Author: Matthew Neils

Date: 4/16/2024
*/

/*------------------------------------------------------------------------------
Calculating Overlaps
------------------------------------------------------------------------------*/
*Importing overlap values from Python code*
import delimited "data/intermediate/RAM_rhos.csv", varnames(1) clear
drop v1
rename sp_id SP_ID
rename name areaid
keep SP_ID areaid rho_*

*Bringing in stock names and areas from RAM database
preserve
tempfile STOCK
import excel "data/raw/RAMLDB v4/Excel/RAMLDB v4.495 (assessment data only).xlsx", sheet("stock") firstrow clear

keep stockid areaid scientificname 

save "`STOCK'", replace
restore

merge 1:m areaid using "`STOCK'", keep(match) nogen

merge 1:m stockid using "data/intermediate/RAM_merged.dta", keep(match) nogen

foreach var of varlist rho_mpa_*{
	
	local i = substr("`var'",9,.)
	gen mpa`i' = (`var' > 0)
	
}

egen anyoverlap = rowmax(mpa*)

*Attaching FAO area information*
preserve
tempfile FAOs
use "data/intermediate/RAM_FAO.dta", clear
rename name areaid
rename FAO_AREA faoarea
*The geometry for RAM area 143 is nonsensical, so it was not properly matched in the Python matching process. I confirmed manually that it is in the Southwest Pacific FAO area*
replace faoarea = "Pacific, Southwest" if SP_ID == "143"
keep areaid faoarea
save `FAOs'
restore

merge m:1 areaid using `FAOs', nogen keep(match)

*Saving set of all 
save "data/intermediate/RAM_model_GLOBAL.dta", replace

*Saving only stocks that overlap with MPAs
keep if anyoverlap > 0
*There are 179 stocks that overlap with some MPA*

save "data/intermediate/RAM_model.dta", replace

/*
FAO Cleaning

Purpose: Import and clean FAO landings data.

Author: Matthew Neils

Date: 4/16/2024
*/

/*
CLEANING, LABELING, and ORGANIZING data to get it in a useable form at the stock (county/faoarea-species) level.
*/

*Bringing in data - data are downloaded from the FAO application FishStatJ v.4.02.07*
*FAO Regional capture fisheries statistics v2022.1.0*
clear all
import delimited "data/raw/FishStat.csv", varnames(1) clear

*Making year variable names meaningful*
foreach v of varlist v*0 v*2 v*4 v*6 v*8{
   local x : variable label `v'
   local y = subinstr("`x'","[","y_",1)
   local z = subinstr("`y'","]","",1)
   rename `v' `z'
}

*Making symbol variable names meaningful and labeling values*
rename s v7
forva i = 7(2)147{

	local j = 1947+(`i'-1)/2
	rename v`i' note_`j' 
	label variable note_`j' "Notes on Landing Values"
	replace note_`j' = "Negligible (<0.5)" if note_`j' == "N"
	replace note_`j' = "Estimated" if note_`j' == "E"
	replace note_`j' = "Mirrored" if note_`j' == "T"
	replace note_`j' = "Imputed" if note_`j' == "I"
	replace note_`j' = "." if note_`j' == "..."

}

*Renaming and cleaning name variable*
rename asfisspeciesname english_name
replace english_name = subinstr(english_name,"[","",1)
replace english_name = subinstr(english_name,"]","",1)

rename faomajorfishingareaname faoarea
rename countryname country
*Country is currently strL and we want it to be str#.*
gen len = length(country)
sum len
recast str24 country, force 
drop len

*Dropping if outcome is in number. This is only for a few rare species (e.g. alligator)*
drop if unitname == "Number"

*Dropping holdover rows from excel.*
drop if country == "FAO. 2022. Fishery and A"
drop if country == "Totals - Number"
drop if country == "Totals - Tonnes - live w"

*Fixing/updating some country names*
replace country = "Turkiye" if country == "TÃ¼rkiye"
replace country = "Venezuela" if country == "Venezuela (Boliv Rep of)"
replace country = "Bolivia" if country == "Bolivia (Plurinat.State)"
replace country = "Curacao" if country == "CuraÃ§ao"
replace country = "Cote d'Ivoire" if country == "CÃ´te d'Ivoire"
replace country = "Reunion" if country == "RÃ©union"
replace country = "Saint Bartholemy" if country == "Saint BarthÃ©lemy"
replace country = "Sudan" if country == "Sudan (former)"
replace country = "Russia" if country == "Un. Sov. Soc. Rep."
replace country = "Russia" if country == "Russian Federation"
replace country = "Falkland / Malvinas Islands" if country == "Falkland Is.(Malvinas)"
replace country = "France" if country == "French Polynesia" 
replace country = "United States" if country == "United States of America"

*Changing some names to match with crosswalks*
replace english_name = "Gemellar's lanternfish" if english_name == "Gemellarâs lanternfish"
replace english_name = "Henslow's swimming crab" if english_name == "Henslowâs swimming crab"
replace english_name = "Rough skate" if english_name == "New Zealand rough skate"
replace english_name = "Ocean surgeonfish" if english_name == "Ocean surgeon"
replace english_name = "Spinetail ray" if english_name == "Spinetail mobula"

/*
MERGING WITH ISSCAAP CROSSWALK TO GAIN MOBIMILITY INFORMATION
*/

*Bringing in a fish name crosswalk*
preserve
tempfile ASFIS
import excel "data/raw/ASFIS_ISSCAAP/ASFIS_sp_2022.xlsx", sheet("ASFIS_All_for_publishing__2022") firstrow case(lower) clear
replace stats_data = "YES" if english_name == "Longtail stingray"
replace stats_data = "YES" if english_name == "Southern stingray"
*Apostrophes are different ASCII characters leading to mismerge for these*
replace english_name = "Gemellar's lanternfish" if strpos(english_name, "Gemellar")
replace english_name = "Henslow's swimming crab" if strpos(english_name, "Henslow")

replace stats_data = "YES" if english_name == "Rough skate"
replace stats_data = "YES" if english_name == "Ocean surgeonfish"
replace stats_data = "YES" if english_name == "Spinetail ray"
keep if stats_data == "YES"
drop if english_name == ""
keep isscaap taxocode a_code scientific_name english_name family order stats_data

*helper variable used to check results*
gen check_english_name = english_name

save `ASFIS'
restore

merge m:1 english_name using `ASFIS'
drop if _merge == 2 

*The majority of stocks merged successfully. The 215 unmerged in master are the ones that we are concerned about. Most of these unmerged stocks seem to have scientific names listed as their names in the FAO dataset. We can therefore do another round of matching using these scientific names.*
gen match2 = ""
replace match2 = english_name if _merge == 1
rename _merge _merge1

preserve
tempfile ASFIS2
import excel "data/raw/ASFIS_ISSCAAP/ASFIS_sp_2022.xlsx", sheet("ASFIS_All_for_publishing__2022") firstrow case(lower) clear
keep if stats_data == "YES"
keep isscaap taxocode a_code scientific_name english_name family order stats_data
gen match2 = scientific_name

*helper variable used to check results*
gen check_scientific_name = scientific_name

* drop the fishes with duplicated scientific_name
duplicates tag scientific_name, gen(duplicated_sci)
drop if duplicated_sci != 0
drop duplicated_sci

save `ASFIS2'
restore

merge m:1 match2 using `ASFIS2', update
drop if _merge == 2
rename _merge _merge2

bro if _merge1 == 1 & _merge2 == 1
*There are only 2 unmerged stocks (Plunket shark an Whiptail stingray) and these stocks do not appear in the crosswalk. A quick search reveals that these stocks are unlikely to be important to the overall analysis.*
drop _merge*
drop match2

drop if english_name == "Plunket shark"
drop if english_name == "Whiptail stingray"

*Removing any inland water stocks. These will not overlap with our MPAs.*
drop if strpos(faoarea, "Inland waters")

*Following Costello et al., we assume that nonmobile stocks are defined at the country-year level, while highly mobile stocks are defined at the FAO area-year level.*
gen stocklevel = country 

*Defining the stocks for which FAO-area level summing is appropriate.*
destring isscaap, replace
replace stocklevel = faoarea if isscaap == 39 | isscaap == 32 | isscaap == 36 | isscaap == 37

*Generating information on the geographic level of the stocks. For grouped stocks this is just FAO area. For nongrouped stocks this is country-FAO.*
gen areaname = stocklevel
replace areaname = faoarea + " " + stocklevel if stocklevel != faoarea

gen stockid = areaname + " " + english_name 

/*------------------------------------------------------------------------------
Collapsing to the appropriate level
------------------------------------------------------------------------------*/
preserve
tempfile FAOAREA
keep stocklevel english_name faoarea areaname scientific_name
duplicates drop 
save `FAOAREA'
restore

collapse (sum) y_*, by(english_name stocklevel faoarea)

*Bringing back in areaname*
merge 1:1 english_name stocklevel faoarea using `FAOAREA', nogen

*Bringing back taxonomic info*
{
preserve
tempfile ASFIS
import excel "data/raw/ASFIS_ISSCAAP/ASFIS_sp_2022.xlsx", sheet("ASFIS_All_for_publishing__2022") firstrow case(lower) clear
replace stats_data = "YES" if english_name == "Longtail stingray"
replace stats_data = "YES" if english_name == "Southern stingray"
*Apostrophes are different ASCII characters leading to mismerge for these*
replace english_name = "Gemellar's lanternfish" if strpos(english_name, "Gemellar")
replace english_name = "Henslow's swimming crab" if strpos(english_name, "Henslow")

replace stats_data = "YES" if english_name == "Rough skate"
replace stats_data = "YES" if english_name == "Ocean surgeonfish"
replace stats_data = "YES" if english_name == "Spinetail ray"
keep if stats_data == "YES"
drop if english_name == ""
keep isscaap taxocode a_code scientific_name english_name family order stats_data
destring isscaap, replace
save `ASFIS'
restore

merge m:1 english_name using `ASFIS'
drop if _merge == 2

*The majority of stocks merged successfully. The 215 unmerged in master are the ones that we are concerned about. Most of these unmerged stocks seem to have scientific names listed as their names in the FAO dataset. We can therefore do another round of matching using these scientific names.*
gen match2 = ""
replace match2 = english_name if _merge == 1
rename _merge _merge1

preserve
tempfile ASFIS2
import excel "data/raw/ASFIS_ISSCAAP/ASFIS_sp_2022.xlsx", sheet("ASFIS_All_for_publishing__2022") firstrow case(lower) clear
keep if stats_data == "YES"
keep isscaap taxocode a_code scientific_name english_name family order stats_data
destring isscaap, replace
gen match2 = scientific_name
sort match2, stable
duplicates drop match2, force
save `ASFIS2'
restore

merge m:1 match2 using `ASFIS2', update
drop if _merge == 2
rename _merge _merge2

bro if _merge1 == 1 & _merge2 == 1
drop _merge*
drop match2
}

save "data/intermediate/FAO_country_wide_GLOBAL", replace

/*------------------------------------------------------------------------------
Reshaping to Long Format
------------------------------------------------------------------------------*/
/*
GENERATING FISHERY-LEVEL INFO about stocks to be used in the model.
*/

*Reshaping data*
use "data/intermediate/FAO_country_wide_GLOBAL", clear
reshape long y_, i(english_name stocklevel faoarea) j(year)
rename y_ landings
recast float landings, force
label var landings "Total Landings (Tonnes)"

*Fishery start date: Following Costello et al. (2012), we start using stock data once they reach 15% of the maximum lifetime recorded landings.*
egen max_landings = max(landings), by(english_name stocklevel faoarea)
label var max_landings "Maximum landings in fishery"
egen start = min(year) if landings >= 0.15*max_landings, by(english_name stocklevel faoarea)
egen start_year = mean(start), by(english_name stocklevel faoarea)
label var start_year "Fishery Start Year"
drop start

*Fishery Age*
gen age = year-start_year
label var age "Age of Fishery"

*Fishery end date*
egen end = max(year) if landings > 0, by(english_name stocklevel faoarea)
egen end_year = mean(end), by(english_name stocklevel faoarea)
label var end_year "Fishery Ending Year"
drop end
*Fisheries that go all the way until 2020 will have missing values*
replace end_year = 2020 if end_year == .

*Dropping years before fisheries began and after they end*
drop if age < 0
drop if year > end_year

*Years to max harvest*
egen max = min(year) if landings == max_landings, by(english_name stocklevel faoarea)
egen max_year = mean(max), by(english_name stocklevel faoarea)
label var max_year "Year of Max Harvest"
drop max

gen years_to_max = max_year-start_year
label var years_to_max "Years (Start to Max)"

*Slope of harvest over first six years.*
gen slope = (landings-landings[_n-6])/6 if age == 6
egen harvest_slope = mean(slope), by(english_name stocklevel faoarea)
label var harvest_slope "Landings Slope (First 6 Years)"
drop slope

*Running harvest ratio (ratio of harvest to maximum prior harvest)*
gen max_yet = .
sum age
forva i = 0/70{
	egen max_yet_`i' = max(landings) if age < `i', by(english_name stocklevel faoarea)
	egen max_yet_all_`i' = mean(max_yet_`i'), by(english_name stocklevel faoarea)
	replace max_yet = max_yet_all_`i' if age == `i'
	drop max_yet*_`i'
}
label var max_yet "Maximum landings before this year"

gen max_harvest_ratio = landings/max_yet
label var max_harvest_ratio "Ratio of harvest to previous maximum"

*Lagged landings*
sort english_name stocklevel faoarea age

gen lag4_landings = landings[_n-4]
gen lag3_landings = landings[_n-3]
gen lag2_landings = landings[_n-2]
gen lag1_landings = landings[_n-1]

replace lag4_landings = . if age <=3
replace lag3_landings = . if age <=2
replace lag2_landings = . if age <=1
replace lag1_landings = . if age <=0

*Average landings*
egen m_landings = mean(landings), by(english_name stocklevel faoarea)
label var m_landings "Mean fishery landings"

*Generating landings scaled by max landings in the fishery*
gen scaled_landings = landings/max_landings
label var scaled_landings "Landings divided by maximum record landings"

gen lag4_scaled_landings = scaled_landings[_n-4]
gen lag3_scaled_landings = scaled_landings[_n-3]
gen lag2_scaled_landings = scaled_landings[_n-2]
gen lag1_scaled_landings = scaled_landings[_n-1]

replace lag4_scaled_landings = . if age <=3
replace lag3_scaled_landings = . if age <=2
replace lag2_scaled_landings = . if age <=1
replace lag1_scaled_landings = . if age <=0

/*
BRINGING IN BIOLOGICAL DATA
*/
*Preparing for merge*
rename scientific_name scientificname

*Some scientific names are missing and the english name is the scientific name. For these, we can just bring over the scientific name.*
replace scientificname = english_name if scientificname == ""

*NEI (nowhere else included) stocks have the abbreviation "spp" in their scientific names. We can use genus-level bioparameters for these.*
replace scientificname = subinstr(scientificname, " spp", "",.)

*Bringing in FishBase data*
merge m:1 scientificname using "Data/Intermediate/life_history.dta"
rename _merge _merge1

*There are a number of species that are in the FAO database but are not in the FishBase database. However, we can get information on genus-level averages*
gen match2 = word(scientificname,1) if _merge == 1

preserve
tempfile MERGE
use "Data/Intermediate/life_history.dta", clear
gen match2 = scientificname if wordcount(scientificname) == 1
drop if match2 == ""
save `MERGE', replace
restore

merge m:1 match2 using `MERGE', update

*The remaining non-merged are largely non-fish, and therefore are not included in Fish-Base. For now we can safely exclude these species, but it would be useful to consider them if we can find appropriate life-history information.*
drop if _merge1 != 3 & _merge != 5
drop _merge*
drop match2

*The exception here is "Marine fishes nei" which are scientifically classified as Actinopterygii, which includes all ray-finned fishes. This is a very broad category that provides almost no information about the species involved, so we drop these from our analysis*
drop if english_name == "Marine fishes nei"

*Because we are looking at marine species, we want to exclude Freshwater and Diadromous fishes*
drop if isscaap <30

*Generating a unique stockid observation*
gen stockid = stocklevel + " " + english_name if stocklevel == faoarea
replace stockid = faoarea + " " + stocklevel + " " + english_name if stocklevel != faoarea

sort stockid year

*Generating length of fishery*
gen numyears = end_year - start_year

save "Data/Intermediate/FAO_country_long_GLOBAL", replace

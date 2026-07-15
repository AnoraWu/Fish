/*
Master Do File

Purpose: Runs all code for the MPA paper

Author: Matthew Neils, Wanru(Anora) Wu

Date: 09/03/2024
*/

*------------------------------------------------------------------------------*
*Setting Directories*
*------------------------------------------------------------------------------*

*** Setting root directories - do not change unless you know the Dropbox file organization
	local platform = 1
	di "`platform'"

	if "`platform'" == "MacComp" {

		* Set root directory
		global rootdir		"/Users/anorawu/Documents/GitHub/Fish"

		* Set Python environment executable path
		* In terminal, activate environment and verify path with:
		* $ conda activate fish
		* $ which python  // should return the following path
		global pythonpath	"/opt/anaconda3/envs/fish/bin/python"

		* Set R executable path
		* In terminal, verify path with:
		* $ which Rscript  // should return the following path
		global rscriptpath	"/usr/local/bin/Rscript"
	}

	else if "`platform'" == "WindowsComp" {
		global rootdir		"C:/Users/`c(username)'/Dropbox/MPA-Fish-Effects-Replication"

		* Set Python environment executable path
		* In terminal, activate environment and verify path with:
		* $ conda activate fish
		* $ which python  // should return the following path
		global pythonpath	"/opt/anaconda3/envs/fish/bin/python"

		* Set R executable path
		* In terminal, verify path with:
		* $ which Rscript  // should return the following path
		global rscriptpath	"/usr/local/bin/Rscript"
	}
	else if "`platform'" == "Acropolis" {
		global rootdir 		"/home/wanru"

		global pythonpath = "home/mneils/.conda/envs/fish-env2/bin/python"
	}



*Whether to run server scripts
local server = 1

*------------------------------------------------------------------------------*
*Data Cleaning/Prep*
*------------------------------------------------------------------------------*

cd "$rootdir"

***Stock Data Cleaning and Overlaps***
***NOTE: Unless noted otherwise, all input and output paths extend from fish/data***

	/* fishlife.R
	 * Purpose: Download the FishLife database 
	 * Input: N/A
	 * Output: /raw/fishlife.csv
	*/ 
rscript using "code/prep/fishlife.R" 

	/* fishlife_cleaning.do
	 * Purpose: Clean the FishLife database for use in stata
	 * Input: /raw/FishLife.csv
	 * Output: /intermediate/life_history.dta
	*/ 
do "code/prep/fishlife_cleaning.do"

	/* FAO_cleaning.do
	 * Purpose: Brings in catch data from FishStatJ and does some initial cleaning 
	 and preparation.
	 * Input: /raw/FishStat.csv, /raw/ASFIS_ISSCAAP/ASFIS_sp_2022.xlsx, /Intermedate/life_history.dta
	 * Output: /intermediate/FAO_country_wide_GLOBAL.dta, /Intermeidate/FAO_country_long_GLOBAL.dta
	*/	 
do "code/prep/FAO_cleaning.do"

	/* access_aquamaps.R
	* Purpose: Extract stock location maps for FAO stocks
	* Input: /intermediate/FAO_country_wide_GLOBAL.dta
	* Output: /Stock Geography/StockNames.csv, /Stock Geography/Stockmap_~.tif
	*/
shell $rscriptpath "code/prep/access_aquamaps.R" 

	/* FAO_overlaps.py
	***NOTE: This script relies on two external sources, MPA shapefiles found at "Cell-Analysis-Replication//intermediate/Marine-Protected-Areas/Marine-Protected-Areas.shp" and a list of final MPAs, manually created from Cell-Analysis-Replication cleaning code. These paths will need to be cleaned up when creating the final replication file.***
	* Purpose: Finds overlaps between FAO stocks and MPAs
	* Input: /Stock Geography/Stockmap_~.tif, /Stock Geography/StockNames.csv, 
	/intermediate/FAO_country_long_GLOBAL.dta, /EEZ Geography/eez_v11.shp
	* Output: /intermediate/FAO_Crosswalk.csv, /Stock Geography/Stock_Shapes.shp, /intermediate/MPA.shp, Intermeidate/FAO_rhos.csv
	*/
shell $pythonpath "code/prep/FAO_overlaps.py"

	/* FAO_overlaps.do
	* Purpose: Attaches stock rhos from python overlap script and bringing in 
	information needed for stock status predictions
	* Input: /intermediate/FAO_country_long_GLOBAL.dta, /intermediate/FAO_rhos.csv, 
	intermediate/FAO_Crosswalk.csv
	* Output: /intermediate/FAO_Pred_Prep_GLOBAL.dta
	*/
do "code/FAO Predictions/FAO_overlaps.do"


	/* RAM_cleaning.do
	 * Purpose: Compiles parameter and time series RAM data, brings in          
	 units and labels, and merges life history data.
	 * Input: /raw/RAM Bioparams.xlsx, RAM Timeseries.xlsx
	 * Output: /intermediate/RAM_timeseries.dta, RAM_param.dta, RAM_merged.dta
	*/	 
do "code/prep/RAM_cleaning.do"





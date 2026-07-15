/*
Master Do File

Purpose: Runs all code for the BioEconomic model and extension sections of the MPA paper

Author: Matthew Neils

Date: 10/7/2023
*/

***NOTE: Unless noted otherwise, all input and output paths extend from MPA-Fish-Effects-Replication/Data***

*** SETTING DIRECTORIES - do not change unless you know the Dropbox file organization
	local platform = "`1'"
	di "`platform'"
	if "`platform'" == "MacComp" {
		global ROOT 		"/Users/`c(username)'/BFI Dropbox/Matthew Neils/MPA-Fish-Effects-Replication"
	}
	else if "`platform'" == "WindowsComp" {
		global ROOT			"C:/Users/`c(username)'/Dropbox/MPA-Fish-Effects-Replication"
	}
	else if "`platform'" == "Acropolis" {
		global ROOT 		"/home/mneils"
	}

	cd $ROOT

	*Preparing python path: set the path to fish-env*
	if "`platform'" == "MacComp" {
	local pythonpath = "/Users/matthewneils/opt/anaconda3/envs/fish-env/bin/python"
	}
	else if "`platform'" == "Acropolis" {
	local pythonpath = "home/mneils/.conda/envs/fish-env2/bin/python"
	}
		
	local rpath = "/usr/local/bin/Rscript"

***Setting Switches - determine whether to install packages, run memory intensive programs, and server scripts

	*Package Installation*
	local packages = 1

	*Whether to run server scripts
	local server = 1

if `packages' == 1{
	
	net install rscript, from("https://raw.githubusercontent.com/reifjulian/rscript/master") replace
	
}

*------------------------------------------------------------------------------*
*Data Cleaning/Prep*
*------------------------------------------------------------------------------*

***Stock Data Cleaning and Overlaps***

	/* FishLife_Cleaning.do
	 * Purpose: Prepares the FishLife database for use in stata
	 * Input: /Raw/FishLife.csv
	 * Output: /Intermediate/life_history.csv
	 * NOTE: This internally calls the R script FishLife.R
	*/Code/Data Prep/	 
do "FishLife_Cleaning.do"

	/* RAM_Cleaning.do
	 * Purpose: Compiles parameter and time series RAM data, brings in          
	 units and labels, and merges life history data.
	 * Input: /Raw/RAM Bioparams.xlsx, RAM Timeseries.xlsx
	 * Output: /Intermediate/RAM_timeseries.dta, RAM_param.dta, RAM_merged.dta
	*/	 
do "Code/Data Prep/RAM_Cleaning.do"

	/* RAM Overlaps.py
	***NOTE: This script relies on two external sources, MPA shapefiles found at "Cell-Analysis-Replication/Data/Intermediate/Marine-Protected-Areas/Marine-Protected-Areas.shp" and a list of final MPAs, manually created from Cell-Analysis-Replication cleaning code. These paths will need to be cleaned up when creating the final replication file.***
	* Purpose: Finds overlaps between RAM stocks and MPAs
	* Input: RAM Geography/results/ram.shp, RAM Geograph/sources/latlon.csv,
	FAO Geography/FAO_AREAS_CWP.shp, Intermediate/Final MPA List.csv
	* Output: Intermediate/MPA.shp, Intermediate/MPA.csv, 
	Intermediate/RAM_rhos.csv, Intermediate/RAM_FAO.dta
	*/
!`pythonpath' "Code/Data Prep/RAM Overlaps.py"

	/* FAO_Cleaning.do
	 * Purpose: Brings in catch data from FishStatJ and does some initial cleaning 
	 and preparation.
	 * Input: /Raw/FishStat.csv, /Raw/ASFIS_ISSCAAP/ASFIS_sp_2022.xlsx, /Intermedate/life_history.dta
	 * Output: /Intermediate/FAO_country_wide_GLOBAL.dta, /Intermeidate/FAO_country_long_GLOBAL.dta
	*/	 
do "Code/Data Prep/FAO_Cleaning.do"

	/* Access_Aquamaps.R
	* Purpose: Extract stock location maps for FAO stocks
	* Input: /Intermediate/FAO_country_wide_GLOBAL.dta
	* Output: /Stock Geography/StockNames.csv, /Stock Geography/Stockmap_~.tif
	*/
global RSCRIPT_PATH "Code/Data Prep/Access_Aquamaps.R"
rscript using "Code/Data Prep/Access_Aquamaps.R", rpath("`rpath'")

	/* FAO Overlaps.py
	***NOTE: This script relies on two external sources, MPA shapefiles found at "Cell-Analysis-Replication/Data/Intermediate/Marine-Protected-Areas/Marine-Protected-Areas.shp" and a list of final MPAs, manually created from Cell-Analysis-Replication cleaning code. These paths will need to be cleaned up when creating the final replication file.***
	* Purpose: Finds overlaps between FAO stocks and MPAs
	* Input: /Stock Geography/Stockmap_~.tif, /Stock Geography/StockNames.csv, 
	/Intermediate/FAO_country_long_GLOBAL.dta, /EEZ Geography/eez_v11.shp
	* Output: /Intermediate/FAO_Crosswalk.csv, /Stock Geography/Stock_Shapes.shp, /Intermediate/MPA.shp, Intermeidate/FAO_rhos.csv
	*/
!`pythonpath' "Code/Data Prep/FAO Overlaps.py"

	/* FAO_Overlaps.do
	* Purpose: Attaches stock rhos from python overlap script and bringing in 
	information needed for stock status predictions
	* Input: /Intermediate/FAO_country_long_GLOBAL.dta, /Intermediate/FAO_rhos.csv, 
	Intermediate/FAO_Crosswalk.csv
	* Output: /Intermediate/FAO_Pred_Prep_GLOBAL.dta
	*/
do "Code/FAO Predictions/FAO_Overlaps.do"

	/* FAO_Predictions.do
	*Purpose: Uses ML model to predict stock status for FAO stocks
	*Input: /Raw/RAMLDB v4/R Data, /Raw/FAO_Resilience, 
	/Intermediate/FAO_Pred_Prep_GLOBAL.dta, /Intermediate/life_history.dta
	*Output: /Intermediate/SRAPriors.csv, /Intermediate/FAO_Pred_Results.csv
	*/
global RSCRPT_PATH "Code/FAO Predictions/FAO_Predictions.R"
rscript using "Code/FAO Predictions/FAO_Predictions.R", rpath("`rpath'")


	/* SAU_Cleaning.do
	***NOTE: This script relies on externally cleaned SAU data from "MPA" Folder, 
	need to clean up data path***
	*Purpose: Brings in price data from Sea Around Us, collapses to the 
	species-year level and prepares to merge with RAM and FAO data
	*Input: ../MPA/data/SAU_EEZ/cleaned/fish_sector_treat.dta, 
	/Intermediate/RAM_model_GLOBAL.dta, /Intermediate/FAO_country_long_GLOBAL
	*Output: /Intermediate/SAU_Cleaned.dta, /Intermediate/RAM_Prices_GLOBAL.dta, /Intermediate/FAO_Prices_GLOBAL.dta
	*/
do "Code/Data Prep/SAU_Cleaning.do"

***Model Prep***

	/* FAO_Model_Prep.do
	*Purpose: Bring in and clean results of ML FAO stock status predictions
	*Input: Intermediate/FAO_Pred_Results.csv, Intermediate/FAO_Pred_Prep_GLOBAL,
	Data/Intermediate/RAM_model.dta
	*Output: Data/Intermediate/FAO_Model_Prepped_GLOBAL, FAO_Model_Prepped_WITHRAMS
	*/
do "Code/Data Prep/FAO_Model_Prep.do"

	/* Econ_Param_Estimation.do
	* Purpose: Estimate the marginal cost of production and add to fish data
	* Input: Intermediate/RAM_model_GLOBAL.dta, RAM_Prices_GLOBAL.dta, 
	FAO_Model_Prepped_GLOBAL.dta, FAO_Prices_GLOBAL.dta
	* Output: Intermediate/BioEc_model_GLOBAL.dta, ALL_BioEc_model_GLOBAL.dta
	*/
do "Code/Data Prep/Econ_Param_Estimation.do"

	/* Final_Model_Prep.do
	* Purpose: Collect deltas for MPAs and calculate rhodeltas
	* Input: 
	/Cell-Analysis-Replication/Results/Deltas/~_MPAs_specific_~_estimates.dta 
	Raw/Mobility and Growth Rates.csv, Intermediate/MPA.csv, 
	Intermediate/ALL_BioEc_model_GLOBAL.dta
	* Output: Intermediate/MPA_delta_years.dta, ALL_Model_Final_GLOBAL, 
	ALL_Model_Final
	*/
do "Code/Data Prep/Final_Model_Prep.do"

***Extensions prep***

	/* Carbon Levels.py
	* Purpose: Calculate average sequestered sea floor carbon levels for MPAS
	* Input: 
	/Cell-Analysis-Replication/Data/Intermediate/Marine-Protected-Areas/
	Marine-Protected-Areas.shp, 
	Intermediate/Final MPA List.csv, FAO Geography/FAO_AREAS_CWP.shp, 
	Raw/Mean carbon_stock.tif
	* Output: Intermediate/mpa_carbon_constants.dta
	*/
!`pythonpath' "Code/Data Prep/Carbon Levels.py"

if `server' == 1{

	/*30 by 30 Prep.py
	* Purpose: Find global cell-level locations of MPAs, seamounts, reefs, and 
	shipping lanes
	* Input: Stock Geography/Stock_Shapes.shp, Intermediate/30 by 30/stock_overlaps.p, EEZ Geography/eez_v11.shp, 
    Raw/Feature Geography/Seamounts/01_Data/Seamounts/Seamounts.shp, Raw/Feature Geography/Warm Reefs/01_Data/WCMC008_CoralReef2021_Py_v4_1.shp, Raw/MPAs/MPAs.shp
	* Output: Intermediate/30 by 30/cell_gdf/cell_gdf.shp, Intermediate/30 by 30/cell_seamounts.p, Intermediate/30 by 30/cell_reefs.p, Intermediate/30 by 30/cell_majorshipping.p, Raw/MPAs/MPAs_grid.shp
	Intermediate/30 by 30/cell_mpa.p, Intermediate/30 by 30/all_eez_overlaps.p
	*/
!`pythonpath' "Code/Data Prep/30 by 30 Prep.py"

	/*30 by 30 Network Prep.py
	* Purpose: Combine data from 30 by 30 prep into one usable file
	* Input: Intermediate/30 by 30/cell_mpa.p, Intermediate/30 by 30/all_eez_overlaps.p, Intermediate/30 by 30/cell_seamounts.p, Intermediate/30 by 30/cell_reefs.p,
	Intermediate/30 by 30/cell_majorshipping.p, Intermediate/30 by 30/stock_overlaps.p, Stock Geography/Stock_Shapes.shp, Intermediate/30 by 30/cell_gdf/cell_gdf.shp, EEZ Geography/eez_v11.shp
	* Output: Intermediate/30 by 30/cell_gdf/cell_gdf_info.csv
	*/
!source "Code/Data Prep/30by30networkprep.sh"

	/*30 by 30 Network.py
	* Purpose: Generate optimized 30 by 30 network based on algorithm. 
	* The Python script does this for each EEZ, so the bash script is used to batch 
	submit each job
	* Input: Stock Geography/Stock_Shapes.shp, EEZ Geography/eez_v11.shp, Intermediate/30 by 30/cell_gdf/cell_gdf_info.csv, FAO_Model_Prepped_WITHRAMS.dta
	* Output: Intermediate/30 by 30/protected_grids/protected_~.p
	*/
!source "Code/Data Prep/30by30.sh"

	/*30 by 30 Combine.py
	* Purpose: Combine individual network runs and save overlaps. 
	* Input: Intermediate/30 by 30/cell_gdf/cell_gdf.shp, ntermediate/30 by 30/protected_grids/protected_~.p
	* Output: Intermediate/30 by 30/cell_gdf/protected_gdf.shp
	*/
!source "Code/Data Prep/30by30_combine.sh"
}
*------------------------------------------------------------------------------*
*Model Main*
*------------------------------------------------------------------------------*
	/* Model_Main.do
	* Purpose: Run the bioeconomic model under estimated and counterfactual 
	protection
	* Input: Intermediate/ALL_Model_Final.dta
	* Output: Final/Model_Results_RD_any_MPA, Final/Model_Results_RD_any_NOMPA, Final/Model_Results_RD_any_NOFISHING,
	Final/Model_Results_AR_any_all_MPA
	*/
do "Code/Model/Model_Main.do"

	/* 3030_Model.do
	* Purpose: Run the bioeconomic model under 30 by 30 counterfactual protection 
	levels
	* Input: Intermediate/ALL_Model_Final_GLOBAL.dta, Intermediate/stock_overlaps_yearly_GLOBAL.csv
	* Output: Intermediate/30by30_baseline, Intermediate/30by30_results_SOMEMPA, Intermediate/30by30_results_MPA
	*/
do "Code/Model/3030_Model.do"

*------------------------------------------------------------------------------*
*Model Appendix*
*------------------------------------------------------------------------------*
if `server' = 1{
	/*GrowthMC.do (4 separate files submitted in parallel)
	* Purpose: Draws values for growth and MSY to test sensitivity
	* Input: Intermediate/FAO_Pred_Results.csv, Intermediate/ALL_model_Final.dta
	* Output: Final/growth_MC_pll.dta
	*/
!source "Code/Appendix/GrowthMC_all.sh"

	/*LambdaMC.do (4 separate files submitted in parallel)
	* Purpose: Draws values of lamb da to test sensitivity
	* Input: Intermediate/ALL_model_Final.dta
	* Output:
	*/
!source "Code/Appendix/LambdaMC_all.sh"

	/*Model_Deltas.do (4 separate files submitted in parallel)
	* Purpose: Runs model using different deltas
	* Input: Intermediate/ALL_Model_Final
	* Output:
	*/
!qsub "Code/Appendix/DeltaHet.qsub"
}

	/*3030_delta_AR_any_all.do
	* Purpose: Runs 3030 model using Angrist-Rokkanen estimates as deltas
	* Input:
	* Output: Final/Model_Results_AR_any_all_MPA, Final/Model_Results_AR_any_all_NOMPA, Final/Model_Results_AR_any_all_NOFISHING,
	Final/Model_Results_AR_any_CIA_1_MPA, Final/Model_Results_AR_any_CIA_1_NOMPA, Final/Model_Results_AR_any_CIA_1_NOFISHING,
	Final/Model_Results_AR_any_CIA_b_MPA, Final/Model_Results_AR_any_CIA_b_NOMPA, Final/Model_Results_AR_any_CIA_b_NOFISHING,
	Final/Model_Results_any_naive_MPA, Final/Model_Results_AR_any_naive_NOMPA, Final/Model_Results_AR_any_naive_NOFISHING,
	*/
do "Code/Appendix/3030_delta_AR_any_all.do"

*------------------------------------------------------------------------------*
*Figures Main*
*------------------------------------------------------------------------------*
	/* Model_Figures.do
	* Purpose: Organizes model results to generate output figures for the 	
	bioeconomic model
	* Input: Intermediate/ALL_Model_Final_GLOBAL, Final/Model_Results_delta_RD_any_MPA, Final/Model_Results_delta_RD_any_NOMPA, Final/Model_Results_delta_RD_any_NOFISHING, Final/Model_Results_delta_AR_any_all_MPA
	* Output: Figure 7, Figure 8, MPA value numbers
	*/
do "Code/Model/Model_Figures.do"

	/* 3030_Figures.do
	* Purpose: Organizes 30 by 30 model results to generate output figures for the bioeconomic model
	* Input: Intermediate/ALL_Model_Final_GLOBAL, Intermediate/FAO_country_long_GLOBAL, Intermediate/30by30_results_SOMEMPA, Intermediate/30by30_results_MPA, Intermediate/30by30_baseline
	* Output: Figure 9
	*/
do "Code/Model/3030_Figures.do"

*------------------------------------------------------------------------------*
*Figures Appendix*
*------------------------------------------------------------------------------*
	/* FAO_Pred_Dists.do
	*Purpose: Plots the distribution of FAO Stock status predictions relative to 
	RAM stocks.
	* Input: Intermediate/FAO_Pred_Results.csv, Intermediate/RAM_merged.dta, Intermediate/RAM_model.dta, Intermediate/FAO_Model_Prepped_WITHRAMS
	* Output: Figure A6
	*/
do "Code/Appnedix/FAO_Pred_Dists.do"

	/* Delta_Het_Figures.do
	* Purpose: Prodcues table describing model outcomes under different deltas
	* Input: Intermediate/MPA_delta_years, Intermediate/ALL_Model_Final, Final/Model_Results_~_MPA.dta, Final/Model_Results_~_NOMPA.dta
	* Output: Table A18
	*/
do "Code/Appendix/Delta_Het_Figures.do"

	/*Future_Counterfactuals_AR_any_all.do
	* Purpose: Generates future counterfactual figures using Angrist-Rokkanen estimates as deltas
	* Input: Intermediate/ALL_Model_Final, Intermediate/MPA_delta_years, Final/Model_Results_delta_AR_any_all_NOMPA, Final/Model_Results_delta_AR_any_all_NOFISHING, Final/Model_Results_delta_AR_any_all_MPA
	* Output: Figure D3
	*/
do "Code/Appendix/Future_Counterfactuals_AR_any_all.do"

	/*3030_delta_AR_any_all_Figures.do
	* Purpose: Generates figures from 3030 model using Angrist-Rokkanen estimates as deltas
	* Input: Intermediate/ALL_Model_Final_GLOBAL, Intermediate/FAO_country_long_GLOBAL, Intermediate/30by30_results_SOMEMPA_AR, Intermediate/30by30_results_MPA_AR, Intermediate/30by30_baseline_AR
	* Output: Figure E1
	*/
do "Code/Appendix/3030_delta_AR_any_all_Figures.do"

	/* Bycatch.do
	*Purpose: Calculates bycatch reduction for select charismatic species
	* Input: Intermediate/ALL_Model_Final, Raw/ASFIS_ISSCAAP/ASFIS_sp_2022.xlsx
	* Output: Figure A8
	*/
do "Code/Appendix/Bycatch.do"
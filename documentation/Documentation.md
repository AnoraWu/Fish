
### prep

### fishlife.R
- **Input**: `FishLife` R package
- **Output**: `/data/raw/FishLife.csv`
- **Purpose of the script**: In the paper _Predicting Life History Parameters for All Fishes Worldwide_, authors James T. Thorson, Stephan B. Munch, Jason M. Cope, and Jin Gao developed a multivariate life history model to predict life history parameters for >32,000 fishes worldwide using data from *FishBase*. They distribute the model and the predicted results in the R package `FishLife`. The script specifically downloads version 2.0.1 of the FishLife R package, which is an updated version of the original R package based on James T. Thorson's paper published in 2020 _Predicting recruitment density dependence and intrinsic growth rate for all fishes worldwide using a data-integrated life-history model_. In this paper, Thorson "developed the first data-integrated life-history model for life-history analysis and demonstrate this approach by combining data from life-history and stock-recruit databases." (Thorson 2020). We extract the `beta_gv` data frame—which contains the predictive mean among traits for every taxon in the tree—from the updated R package `FishLife` and then exports it to a CSV format. The extracted data includes biological parameters such as the Von Bertalanffy growth coefficients which are later used in the bioeconomic model.
- **Reference:** 
	1. Thorson, J.T., Munch S.B., Cope J.M., and J. Gao, “Predicting life history parameters for all fishes worldwide,” *Ecological Applications*, 2017, *27* (8).
	2. Thorson, James T. "Predicting recruitment density dependence and intrinsic growth rate for all fishes worldwide using a data-integrated life-history model." _Fish and Fisheries_, 2020, *21*(2).

### fishlife_cleaning.do
- **Input**: `data/raw/FishLife.csv`
- **Output**: `data/intermediate/life_history.dta`
- **Purpose of the script**: This script cleans the extracted data containing biological parameters of fishes from the FishLife R package and then export the data as life_history.dta. 
- **Notes**：In cleaning the data, we only kept fishes with data in fishbase, rather than using predictive results. The variable `scientificname` represents the species' name (Genus Species) or the most specific identifier (from the class level downward) of the fish.

### FAO_cleaning.do
- **Input**: 
	1. `data/raw/FishStat.csv`, downloaded from FishStatJ v.4.02.07, FAO Regional capture fisheries statistics --  Global capture production
	2. `data/raw/ASFIS_ISSCAAP/ASFIS_sp_2022.xlsx` The taxonomic code descriptors are taken from the "ASFIS list of species for fishery statistics purposes" (version 2022).
	3. `data/intermediate/life_history.dta`
- **Output**: 
	1. `data/intermediate/FAO_country_wide_GLOBAL.dta`
	2. `data/intermediate/FAO_country_long_GLOBAL.dta`
- **Purpose of the script**: This script processes and cleans CSV data files downloaded from FishStatJ, which covers annual series of capture production from 1950 to 2020. According to Global capture production - General notes, the data relate to nominal catches of fish, crustaceans, molluscs, aquatic mammals, other aquatic animals, residues and plants taken for commercial, industrial, recreational and subsistence purposes from inland, brackish and marine waters. This script first cleans the species' names and country names, collapses the catches to `english_name` and `stocklevel` levels, and then it merges with ASFIS (Aquatic Sciences and Fisheries Information System) codes and taxonomic details to create the primary file `FAO_country_wide_GLOBAL.dta`. Once cleaned, the data is reshaped and merged with `life_history.dta`. This final dataset, stored in `FAO_country_long_GLOBAL.dta`, combines catch information, species codes, taxonomic classifications, and biological parameters of FAO fish stocks.
- **Reference**: 
	1. FAO, “FAO Fisheries and Aquaculture -FishStatJ - Software for Fishery and Aquaculture Statistical Time Series,” 2022.
	2. FAO. 2023. ASFIS List of Species for Fishery Statistics Purposes. In: Fisheries and Aquaculture. https://www.fao.org/fishery/en/collection/asfis
	3. Costello, Christopher, Daniel Ovando, Ray Hilborn, Steven D. Gaines, Olivier Deschenes, and Sarah E. Lester. “Status and Solutions for the World’s Unassessed Fisheries.” Science 338, no. 6106 (October 26, 2012): 517–20. https://doi.org/10.1126/science.1223389.
- **Note**: We removed any inland water stocks as those will not overlap with the MPAs. Following Costello et al. (2012), we assume that nonmobile stocks are defined at the country-year level, while highly mobile stocks are defined at the FAO area-year level.


### access_aquamaps.R
- **Input**:
	1. `aquamapsdata` R package. 
	2. `data/intermediate/FAO_country_wide_GLOBAL.dta`
- **Output**: 
	1. `data/intermediate/Stock Geography/StockNames.csv` 
	2. `data/intermediate/Stock Geography/Stockmap_~.tif`
- **Purpose of the script**: AquaMaps provides predicted marine ranges for species based on sightings, expert opinions, and computer-generated ecological envelopes that can support a given species (Kaschner et al., 2019). The `aquamapsdata` R package allows users to download and create a local SQLite database with datasets from AquaMaps.org. For each FAO stock (stored in `FAO_country_wide_GLOBAL.dta`), we extract its species, and define each species's range as the union of cells where the AquaMaps probability of occurrence is greater than 0.5. The script stored the species' range into `Stockmap_~.tif` files for later use. All the species' names are stored in `StockNames.csv`. 
- **Reference**:
	1. Kaschner, K., K. Kesner-Reyes, C. Garilao, J. Segschneider, Rius-Barile, T. J. Rees, and R. Froese, “Aquamaps: Predicted range mpas for aquatic species,” 2019. Retrieved from https://www.aquamaps.org.
	2. Skyttner M (2020). _aquamapsdata: Curated Data From AquaMaps.Org_. R package version 0.1.6, commit 1d45f804eae8136bde4fe7d7385d2c21dff6ffe5,<https://github.com/raquamaps/aquamapsdata>.

### FAO_overlaps.py
- **Input**:
	1. `data/intermediate/Stock Geography/Stockmap_~.tif`
	2. `data/intermediate/Stock Geography/StockNames.csv` 
	3. `data/intermediate/FAO_country_long_GLOBAL.dta`
	4. `data/raw/FAO Geography/FAO_AREAS_CWP.shp`, downloaded from FAO Map catalog -- FAO Statistical Areas for Fishery Purposes (https://www.fao.org/fishery/en/area/search)
	5. `data/intermediate/EEZ Geography/eez_v11.shp`, Maritime Boundaries Geodatabase: Maritime Boundaries and Exclusive Economic Zones downloaded from https://www.vliz.be/en/imis?dasid=6316&doiid=386
	6. `data/intermediate/Marine-Protected-Areas/Marine-Protected-Areas.shp`
	7. `data/raw/Final MPA List.csv`
- **Output**: 
	1. `data/intermediate/Stock Geography/Stock_Shapes.shp`
	2. `data/intermediate/FAO_Crosswalk.csv`
	3. `data/intermediate/MPA.shp`
	4. `data/intermediate/FAO_rhos.csv`
- **Purpose of the script**: Since our unit of analysis is the stock rather than the species, the script calculates the range of an FAO stock as the intersection of the species' range (stored in `Stockmap_~.tif`) with either the FAO area or the EEZ-FAO area, depending on whether the stock is classified as high-mobility or non-high-mobility. The resulting stock maps are cleaned and stored in `Stock_Shapes.shp`. After determining each stock's range, the script calculates the percentage of overlap between each stock and each Marine Protected Area and exports the results to `FAO_rhos.csv`.
- **Reference**:
	1. Flanders Marine Institute (2019). Maritime Boundaries Geodatabase: Maritime Boundaries and Exclusive Economic Zones (200NM), version 11. Available online at https://www.marineregions.org/. [https://doi.org/10.14284/386](https://doi.org/10.14284/386)
	2. FAO, 2020. FAO Statistical Areas for Fishery Purposes. In: FAO Fisheries and Aquaculture Division [online]. Rome. [Cited <September 27th 2022>] https://www.fao.org/fishery/en/area/search
- **Caveat**: `Marine-Protected-Areas` and `Final MPA List.csv`doesn't know the datasource. 

### FAO_overlaps.do
- **Input**:
	1. `data/intermediate/FAO_country_long_GLOBAL.dta`
	2. `data/intermediate/FAO_rhos.csv`
	3. `data/intermediate/FAO_Crosswalk.csv`
- **Output**: 
	1. `data/intermediate/FAO_Pred_Prep_GLOBAL.dta`
- **Purpose of the script**: This script merged the `FAO_rhos.csv` file, which contains information about FAO fish stocks' percentage of overlap with each of the MPAs, with `FAO_country_long_GLOBAL.dta`, which includes both catch information and biological parameters about FAO fish stocks. For FAO stocks that have no maps (so its overlap with MPA could not be calculated), they are dropped, but they only has 14.5% of total landings. The data is then cleaned for preparation of Ovando ML. 


### RAM_cleaning.do
- **Input**: `data/raw/RAMLDB v4/Excel/RAMLDB v4.495 (assessment data only).xlsx`, 
- **Output**: 
	1. `data/intermediate/RAM_param.dta`
	2. `data/intermediate/RAM_timeseries.dta`
	3. `data/intermediate/RAM_merged.dta`
- **Purpose of the script**: The RAM Legacy Stock Assessment database compiles independent RAM stock assessments, offering information for half of the global catch. This script utilizes version 4.495 of the RAM Legacy Stock Assessment database. This script extracts bioparameters of the RAM stocks, along with all time series data, cleans the data, and then store the information into `RAM_param.dta` and `RAM_timeseries.dta` respectively. Then, the script combines the cleaned datasets into `data/intermediate/RAM_merged.dta`.
- **Reference**:
	1. RAM database, “RAM Legacy Stock Assessment database v4.495 \[data set\],” 2021.
	2. Costello, C., D. Ovando, and T. Clavelle et al., “Global fishery prospects under contrasting management regimes,” Proceedings of the National Academy of Sciences, 2016, 113 (18), 5125–5129

	

### RAM_overlaps.py 
- **Input**: 
	1. `data/RAM Geography/results/ram.shp`, compiled by Rising (2017), contains the shapefile of assessment regions ("https://zenodo.org/records/834755")
	2. `data/RAM Geography/sources/latlon.csv`, compiled by Rising (2017), contains the region descriptions for each assessment region. ("https://zenodo.org/records/834755")
	3. `data/FAO Geography/FAO_AREAS_CWP.shp`, downloaded from FAO Map catalog -- FAO Statistical Areas for Fishery Purposes ("https://data.apps.fao.org/map/catalog/srv/eng/catalog.search#/metadata/ac02a460-da52-11dc-9d70-0017f293bd28") 
	4. `Marine-Protected-Areas.shp`(need change)
	5. `Final MPA List.csv` (need change)
- **Output**: 
	1. `data/intermediate/MPA.shp`
	2. `data/intermediate/RAM_rhos.csv`
	3. `data/intermediate/RAM_FAO.dta`
- **Purpose of the script**: The RAM Legacy Stock Assessment Database Geospatial Regions was compiled by Rising in 2017. It contains geographic information for the areas corresponding to stocks listed in the RAM Legacy Stock Assessment Database. For each RAM stock area, the script calculates the percentage of spatial overlap with each Marine Protected Area (MPA) and exports the results—along with relevant area information and location data—to a file named `RAM_rhos.csv`. `MPA.shp` is the maps of MPAs that are in the `Final MPA List.csv`. In addition, the script iterates over each RAM stock area to identify the FAO area with the greatest spatial overlap. This mapping is then saved in a separate file, `RAM_FAO.dta`.
- **Reference**: 
	1. Rising, J., “RAM Legacy Stock Assessment database Geospatial Regions \[data set\],” 2017.
- **Caveat**: Input 4 and 5 are outputs from scripts we haven't checked yet. `Input`, `Purpose`, and `Reference` need changes. Need to change directories in the script. `MPA.csv`'s purpose should be added. 

### RAM_overlaps.do
- **Input**:
	1. `data/intermediate/RAM_rhos.csv`
	2. `data/raw/RAMLDB v4/Excel/RAMLDB v4.495 (assessment data only).xlsx`
	3. `data/intermediate/RAM_merged.dta`
	4. `data/intermediate/RAM_FAO.dta`
- **Output**: 
	1. `data/intermediate/RAM_model_GLOBAL.dta`
	2. `data/intermediate/RAM_model.dta`
- **Purpose of the script**: This script merged the `RAM_rhos.csv` file, which contains information about each RAM fish stocks' percentage of overlap with each of the MPAs, with `RAM_merged.dta`, which stores bioparameters and the time series data of the RAM stocks. Then, `RAM_FAO.dta`,which contains the FAO area with the greatest spatial overlap with each of the RAM stocks, is merged with the above dataset to create `RAM_model_GLOBAL.dta`. Saving only stocks that overlap with MPAs, the script then saves the data in `RAM_model.dta`.
- **Reference**:

### FAO_Predictions.R
- **Input**:
	1. `data/raw/RAMLDB v4/R Data`
	2. `data/raw/FAO_Resilience`(resilience classifications retrieved from FishBase on 11/15/2022 using ‘resilience’ r package: https://rdrr.io/github/cfree14/datalimited2/man/resilience.html.)
	3. `data/intermediate/FAO_Pred_Prep_GLOBAL.dta`
	4. `data/intermediate/life_history.dta`
- **Output**: 
	1. `data/intermediate/SRAPriors.csv`
	2. `data/intermediate/FAO_Pred_Results.csv`
- **Purpose of the script**: 
- **Reference**:


### SAU_Cleaning.do
- **Input**:
	1. `data/intermediate/SAU_EEZ/cleaned/fish_sector_treat.dta` (data source unsure)
	2. `data/intermediate/RAM_model_GLOBAL.dta` (data source unsure)
	3. `data/intermediate/FAO_country_long_GLOBAL.dta`
- **Output**: 
	1. `data/intermediate/SAU_Cleaned.dta` 
	2. `/Intermediate/RAM_Prices_GLOBAL.dta` 
	3. `/Intermediate/FAO_Prices_GLOBAL.dta`
- **Purpose of the script**: 
- **Reference**:

### FAO_Model_Prep.do
- **Input**:
	1. `data/intermediate/FAO_Pred_Results.csv`
	2. `data/intermediate/FAO_Pred_Prep_GLOBAL`
	3. `data/intermediate/RAM_model.dta`
	4. `data/raw/Mobility and Growth Rates.csv`
- **Output**: 
	1. `data/intermediate/FAO_Model_Prepped_GLOBAL`
	2. `data/intermediate/FAO_Model_Prepped_WITHRAMS`
- **Purpose of the script**: 
- **Reference**:

### 
- **Input**:
	1. 
- **Output**: 
	1. 
- **Purpose of the script**: 
- **Reference**:

### 
- **Input**:
	1. 
- **Output**: 
	1. 
- **Purpose of the script**: 
- **Reference**:

Flanders Marine Institute (2023). Maritime Boundaries Geodatabase: Maritime Boundaries and Exclusive Economic Zones (200NM), version 12. Available online at https://www.marineregions.org/. https://doi.org/10.14284/632
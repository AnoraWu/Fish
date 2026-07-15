1. `life_history.dta`: the data frame, which contains the predictive mean among traits for every taxon in the tree, is stored into a CSV format. The extracted data includes biological parameters such as the Von Bertalanffy growth coefficients, maximum length, maximum weight, and length at maturity. 
	- `scientificname` (Genus Species or the last word)
	- the stocks include FishBase and RAM Legacy database
	- predicted results are dropped

2. `FAO_country_wide_GLOBAL.dta`: This script first cleans the species' names and country names, collapses the catches to `english_name`, `stocklevel` and `faoarea` levels and then it merges with ASFIS (Aquatic Sciences and Fisheries Information System) codes and taxonomic details to create the primary file `FAO_country_wide_GLOBAL.dta`.
	- `english_name`, `faoarea`, `country`
	- `stocklevel (= country or faoarea)`
	- `areaname = faoarea or = country faoarea`
	- `stockid` = `stocklevel english_name` or `faoarea stocklevel english_name`
same scientific name can correspond to multiple english name (thus different level of mobility)
根据 english name merges with crosswalk
但是根据 scientific map 找 range

3. `FAO_country_long_GLOBAL.dta`: This final dataset combines catch information, species codes, taxonomic classifications, and biological parameters of FAO fish stocks.
	- `start_year` 
		= min(year) if landings >= 0.15*max_landings, by(english_name stocklevel)
	- `stockid` = `stocklevel english_name` or `faoarea stocklevel english_name`
	- `scientific_name` is different from the one in `FAO_country_wide_GLOBAL.dta`:

```stata
rename scientific_name scientificname
replace scientificname = english_name if scientificname == ""
*NEI (nowhere else included) stocks have the abbreviation "spp" in their scientific names. We can use genus-level bioparameters for these.*
replace scientificname = subinstr(scientificname, " spp", "",.) 
```

4. `Stocknames.csv`:  `scientific_name` in `FAO_country_wide_GLOBAL.dta` without empty stock names.

5. `StockMap_", i`: `scientific_name` in `FAO_country_wide_GLOBAL.dta` which can be search by the function `am_search_fuzzy` (or has map). 

6. `Stock_Shapes.shp`: 
```
stock_maps -- {stockname:range} stockname from wide and map

stock_info -- FAO_country_long_GLOBAL.dta, ['stockid', 'faoarea','areaname','stocklevel','scientificname'].drop_duplicates() and isin(stock_maps.keys())\

stock_info_maps -- stock_info + map (intersection with species range, FAO, EEZ) as geometry

maps_df -- stock_info_maps with valid geomotry and its `stockid` (`stocklevel english_name` or `faoarea stocklevel english_name`), stored in Stock_Shapes.shp 
```

7. `FAO_Crosswalk.csv`: FAO geography information. 
```stata
fao = fao[fao['F_LEVEL']== "MAJOR"]
fao["NUM"] = fao.index
```

8. `MPA.shp`: `Marine-Protected-Areas.shp` and `mpa = gdf.loc[gdf['NAME'].isin(keys)]` where keys is modified `Final MPA List`

9. `FAO_rhos.csv`: `maps_df` stockid and each stock's overlap with mpa. so that each stock name is inherited from ` FAO_country_long_GLOBAL.dta`.
 with drop duplicates and keep stocks that have maps (*3835 stocks have no maps, but these are only 14.5% of total landings.*)

10.  `FAO_Pred_Prep_GLOBAL.dta`: This script merged the `FAO_rhos.csv` file, which contains information about FAO fish stocks' percentage of overlap with each of the MPAs, with `FAO_country_long_GLOBAL.dta`, which includes both catch information and biological parameters about FAO fish stocks, and the faoarea's code `FAO_Crosswalk.csv`. For FAO stocks that have no maps (so its overlap with MPA could not be calculated), they are dropped as they only has 14.5% of total landings. The data is then cleaned for preparation of Ovando ML. 
	- Keeping only catch series of at least 25 years
	- keep `stockid isscaap scientificname landings year num_years c_div_maxc c_div_meanc c_roll_maxc c_roll_meanc metric fishery_year fao_area_code ln_loo k ln_winfinity tmax tm m lm temperature ln_var rho ln_masps ln_margsd h logitbound_h ln_fmsy_over_m ln_fmsy ln_r r ln_g g m_v_k linf_v_lmat english_name stocklevel faoarea scientificname mpa* rho* `

11. `RAM_param.dta`: `"Stock ID" "Stock name"` and other parameters from RAMLDB. 

12. `RAM_timeseries.dta`: Time series values. Bring in unit and merge, drop stocks with unrealistic biomass or extraction levels, drop years before 1950, keep years that have more than 25 years of data, drop stocks with jump in years, dropping years before first catch. 

13. `RAM_merged`: `RAM_param.dta` merged with `RAM_timeseries.dta` and generated a lot of parameters. Dropping stocks with MSY > Bmsy (only 4 stocks)

14. `MPA.csv`: load the MPA areas geometry `Marine-Protected-Areas.shp` and only keeps those in the `Final MPA List.csv`. After generating `MPA.shp`, we have 
```
mpa.insert(0,'NUM', range(1,176))

#Fixing index
mpa["Index"] = (mpa.loc[:,"NUM"] - 1)
mpa.set_index("Index", inplace = True)
mpa[['NUM', 'NAME', 'STATUS_YR', 'IUCN_CAT', 'WDPAID', 'geometry']].to_csv("data/intermediate/MPA.csv")
```

15. 


#import packages
import multiprocessing 
import rasterio
import rasterio.warp
from rasterio.plot import show
from rasterio.features import shapes
import os
import shapely as shp
import fiona
import math
import time
import matplotlib.pyplot as plt
import geopandas as gpd
import pandas as pd
import numpy as np
from shapely.validation import explain_validity
from shapely.geometry import Point
from shapely.errors import TopologicalError
from shapely.strtree import STRtree
from shapely.ops import unary_union
from shapely import wkt
from tqdm import tqdm
import random
import warnings
warnings.filterwarnings("ignore", category=RuntimeWarning)


def fao_overlap_one(FAO,MPA,maps_df,mpa):

    if maps_df.loc[maps_df.index == FAO]['geometry'].is_empty.any():
        overlap = 999999
            
    else:
        faorange = maps_df[maps_df.index == FAO].to_crs(crs="esri:54034").buffer(0)
        faoarea = faorange.area.sum()
        
        if faoarea == 0:
            overlap = 999999

        else:
            mpaid = mpa.loc[mpa["NUM"] == MPA].to_crs(crs="esri:54034").buffer(0)
            if mpaid.is_empty:
                overlap = 999999
            else:
                mparange = gpd.GeoDataFrame(geometry=gpd.GeoSeries(mpaid))
                
                if faorange.intersects(mparange, align = False).any():
                    # keep_geom_type=False because `keep_geom_type` does not support GeometryCollection, this will not affect the calculation of area
                    mpaoverlap = gpd.overlay(faorange, mparange, how = "intersection", keep_geom_type=False)
                        
                    if mpaoverlap['geometry'].is_valid.min() == False:
                        mpaoverlap['geometry'] = mpaoverlap['geometry'].buffer(0)
                        if mpaoverlap['geometry'].is_valid.min() == False:
                            print("Invalid mpa overlap")
                            
                    mpaarea = mpaoverlap.area.sum()
                        
                else:
                    mpaarea = 0
                
                overlap = mpaarea/faoarea
            
    return overlap

def fao_overlap_all(FAO, maps_df, mpa):

    list_fao = [FAO]*(len(mpa))
    # datalist_maps_df and datalist_mpa are lists of data frames maps_df and mpa respectively. 
    datalist_maps_df = [maps_df]*(len(mpa))
    datalist_mpa = [mpa]*(len(mpa))

    fao_overlaps = map(fao_overlap_one,list_fao,range(1,len(mpa)+1), datalist_maps_df, datalist_mpa)
    
    return list(fao_overlaps)

def get_geographies(stocknum,stock_info,stock_maps,fao,eez):
    
    #for each stockid, extract its scientific name
    sciname = stock_info.loc[stocknum,'scientificname']
    
    #Extracting stock range shape from dictionary
    #find its scientific name's corresponding map (each scientific name may have correspondence with multiple stock id)
    stockrange = gpd.GeoDataFrame(geometry=gpd.GeoSeries(stock_maps[sciname]),crs="EPSG:4326")
    
    #For high mobility stocks taking intersection of range and FAO area:
    #stocklevel and scientificname combined is not a unique identifier, so there will be a few stock id have the same trimmed map
    stocklevel = stock_info.loc[stocknum,'stocklevel']
    faoarea   = stock_info.loc[stocknum,'faoarea']
    if stocklevel == faoarea:
        trimmed_map = gpd.overlay(stockrange, fao.loc[fao['NAME_EN'] == faoarea].to_crs('EPSG:4326'), how = 'intersection', keep_geom_type=False)['geometry']
        if trimmed_map.is_valid.min() == False:
            trimmed_map = trimmed_map.buffer(0)
    
    #For non-high mobility stocks taking intersection of range, FAO area, and EEZ:
    else:
        map_EEZ = gpd.overlay(stockrange, eez.loc[eez['SOVEREIGN1'] == stocklevel].to_crs('EPSG:4326'), how = 'intersection', keep_geom_type=False)['geometry']
        if map_EEZ.is_valid.min() == False:
            map_EEZ = map_EEZ.buffer(0)
        map_EEZ = gpd.GeoDataFrame(geometry=gpd.GeoSeries(map_EEZ))
        if len(map_EEZ) == 0:
            trimmed_map = ""
        else:
            trimmed_map = gpd.overlay(map_EEZ, fao.loc[fao['NAME_EN'] == faoarea].to_crs('EPSG:4326'), how = 'intersection', keep_geom_type=False)['geometry']
            if trimmed_map.is_valid.min() == False:
                trimmed_map = trimmed_map.buffer(0)
    
    return [stock_info.loc[stocknum,'stockid'], trimmed_map]

if __name__ == "__main__":

    stocknames = pd.read_csv("data/intermediate/Stock Geography/StockNames.csv")

    #stock_maps is the dictionary of scientific names and their geometries
    stock_maps = {}
    mask = None
    for x in range(1,len(stocknames)+1):
        
        try: 
            with rasterio.Env():
                with rasterio.open('data/intermediate/Stock Geography/StockMap_%d.tif' % (x)) as src: 
                    image = src.read(1) # first band
                    results = (
                    {'properties': {'raster_val': v}, 'geometry': s}
                    for i, (s, v)  # s is the GeoJSON object, v is the value attached
                    in enumerate(
                        shapes(image, mask=mask, transform=src.transform)))
            
            #Turning into GeoDataFrame        
            geoms = list(results)
            raster_poly = gpd.GeoDataFrame.from_features(geoms)
            #Keeping only valid cells and combining into multipolygon
            raster_poly = raster_poly[raster_poly['raster_val']>0.5].dissolve()
        
            #Save to dictionary(Aquamaps rasters use CRS EPSG:4326)
            stock_maps[stocknames.iloc[x-1,0]] = raster_poly['geometry'].set_crs(crs = 'EPSG:4326')
            print(stocknames.iloc[x-1,0])
            
        except:
            print("No map for %d" % (x))
            continue
        
    #Bringing in stock location info
    fao_info = pd.read_stata("data/intermediate/FAO_country_long_GLOBAL.dta")
    fao_info = fao_info.loc[:,['stockid', 'faoarea','areaname','stocklevel','scientificname']].drop_duplicates()

    #Keeping only stocks for which we have maps for that species
    #stock_info is using stockid as the unique identifier, but only keeping those whose scientific name have maps
    stock_info = fao_info[fao_info['scientificname'].isin(stock_maps.keys())].reset_index()

    #Bringing in FAO and EEZ shapefiles

    #Bringing in FAO information
    fao = gpd.read_file("data/raw/FAO Geography/FAO_AREAS_CWP.shp")
    fao = fao[fao['F_LEVEL']== "MAJOR"]
    fao["NUM"] = fao.index #use fao index as the NUM variable here
    fao.to_csv("data/intermediate/FAO_Crosswalk.csv")

    #Bringing in EEZ information
    eez = gpd.read_file("data/raw/EEZ Geography/eez_v11.shp")
    #The FAO data contains information on country of landing, meaning that the SOVEREIGN1 variable contains the most detailed relevant geographic info.
    #The only exception is Falkland / Malvinas Is., which are disputed and therefore appear in the FAO data.
    eez.loc[eez['TERRITORY1'] == "Falkland / Malvinas Islands","SOVEREIGN1"] = "Falkland / Malvinas Islands"
    eez.insert(0,'NUM', range(0,len(eez)))

    #Getting geographies
    args = [(i, stock_info, stock_maps, fao, eez) for i in range(0,len(stock_info))]
    with multiprocessing.Pool(processes=8) as pool:
        trimmed_maps = list(pool.starmap(get_geographies, args))

    stock_info_maps = stock_info
    stock_info_maps['geometry'] = 0
    stock_info_maps['geometry'] = stock_info_maps['stockid'].map(dict(trimmed_maps))

    #Turning stock shapefiles into a geoseries in order to save
    # Initialize the map_series and map_names 
    # the first entry has empty geometry, so we start from the second
    map_series = gpd.GeoDataFrame(stock_info_maps['geometry'][1], crs = 4326).dissolve() 
    map_series.index = [1]
    map_names = {1: stock_info_maps['stockid'][1]}

    # Loop through the rest of the geometries in stock_info_maps
    for x in range(2,len(stock_info_maps)):
        
        #Skipping stocks with no overlap
        if type(stock_info_maps['geometry'][x]) == gpd.geoseries.GeoSeries:
            map_geom = gpd.GeoDataFrame(stock_info_maps['geometry'][x], crs = 4326).dissolve()
            
            # Check if the geometry is not empty
            if len(map_geom) == 0:
                continue
            if map_geom.empty:
                continue
            if map_geom.is_empty.all():
                continue
            
            map_geom.index = [x]
            map_series = pd.concat([map_series, map_geom])
            map_names[x] = stock_info_maps['stockid'][x]
            continue
        if type(stock_info_maps['geometry'][x]) == str:
            continue
        else:
            print(stock_info_maps['geometry'][x])
            print(f"Invalid geometry at index {x}: {stock_info_maps['geometry'][x]}")

    maps_df = map_series
    maps_df.reset_index(inplace=True)
    maps_df['stockid'] = maps_df['index'].map(map_names)

    #Geometry-collections with points cause troubles for exporting. Removing points from geometry collections
    for i, row in maps_df.iterrows():
        if type(row.geometry) == shp.geometry.collection.GeometryCollection:

            # get the polygon and only keep the polygon 
            shapes = []
            for shape in row.geometry.geoms:
                if type(shape) == shp.geometry.polygon.Polygon:
                    shapes.append(shape)
            maps_df.loc[i,"geometry"] = shp.geometry.MultiPolygon(shapes)

    maps_df.drop(columns=["index"],inplace=True)
    maps_df = maps_df.reset_index()
    try:
        maps_df.drop('index',axis = 1, inplace = True)
    except:
        print('No column to drop')
    maps_df.to_file("data/intermediate/Stock Geography/Stock_Shapes.shp", mode='w')

    #Deleting to save memory
    del stock_maps
    del stock_info_maps
    del map_series
        
    ###Generating overlap with MPAs
    #Bring in MPA Data
    gdf = gpd.read_file("data/intermediate/Marine-Protected-Areas/Marine-Protected-Areas.shp")

    #Keep only the MPAs that are included in the final sample

    #Loading in list of MPAs in the sample
    mpa_sample = pd.read_csv("data/intermediate/Final MPA List.csv", encoding="latin1")

    #Adjusting names with unrecognized characters
    mpa_sample.loc[mpa_sample['mpa_name'] == "Volcanes de fango del Golfo de Cadiz",'mpa_name'] = "Volcanes de fango del Golfo de Cádiz"
    mpa_sample.loc[mpa_sample['mpa_name'] == "SGaan Kinghlas - Bowie Seamount Marine Protected Area",'mpa_name'] = "SGaan Kinghlas – Bowie Seamount Marine Protected Area"
    mpa_sample.loc[mpa_sample['mpa_name'] == "Namuncura - Banco Burdwood",'mpa_name'] = "Namuncurá - Banco Burdwood"
    mpa_sample.loc[mpa_sample['mpa_name'] == "Oceanica do Corvo",'mpa_name'] = "Oceânica do Corvo"
    mpa_sample.loc[mpa_sample['mpa_name'] == "Oceanica do Faial",'mpa_name'] = "Oceânica do Faial"
    mpa_sample.loc[mpa_sample['mpa_name'] == "Papahanaumokuakea Marine National Monument",'mpa_name'] = "Papahānaumokuākea Marine National Monument"
    mpa_sample.loc[mpa_sample['mpa_name'] == "Area de Protecao Ambiental do Arquipelago De Sao Pedro e Sao Paulo",'mpa_name'] = "Área de Proteção Ambiental do Arquipelago De Sao Pedro e Sao Paulo"
    mpa_sample.loc[mpa_sample['mpa_name'] == "Lobul sudic al Campului de Phyllophora al lui Zernov",'mpa_name'] = "Lobul sudic al Câmpului de Phyllophora al lui Zernov"
    mpa_sample.loc[mpa_sample['mpa_name'] == "Banco de la Concepcion",'mpa_name'] = "Banco de la Concepción"
    mpa_sample.loc[mpa_sample['mpa_name'] == "Mar de Juan Fernandez",'mpa_name'] = "Mar de Juan Fernández"
    mpa_sample.loc[mpa_sample['mpa_name'] == "Parque Estadual Marinho Do Parcel De Manuel Luis",'mpa_name'] = "Parque Estadual Marinho Do Parcel De Manuel Luís"
    mpa_sample.loc[mpa_sample['mpa_name'] == "Pacifico Mexicano Profundo",'mpa_name'] = "Pacífico Mexicano Profundo"
    mpa_sample.loc[mpa_sample['mpa_name'] == "Campos Hidrotermais a Sudoeste dos Acores",'mpa_name'] = "Campos Hidrotermais a Sudoeste dos Açores"
    mpa_sample.loc[mpa_sample['mpa_name'] == "Tete de Canyon du Cap Ferret",'mpa_name'] = "Tête de Canyon du Cap Ferret"
    mpa_sample.loc[mpa_sample['mpa_name'] == "Arquipelago Submarino do Meteor",'mpa_name'] = "Arquipélago Submarino do Meteor"
    mpa_sample.loc[mpa_sample['mpa_name'] == "Islas Diego Ramirez y Paso Drake",'mpa_name'] = "Islas Diego Ramírez y Paso Drake"

    keys = list(mpa_sample['mpa_name'])

    #Keeping MPAs with a name in sample
    mpa = gdf.loc[gdf['NAME'].isin(keys)]

    mpa.to_file("data/intermediate/MPA.shp", mode='w')

    mpa.insert(0,'NUM', range(1,len(mpa)+1))

    #Fixing index
    mpa["Index"] = (mpa.loc[:,"NUM"] - 1)
    mpa.set_index("Index", inplace = True)

    #Running overlaps in parallel
    args = [(i, maps_df, mpa) for i in range(0,len(maps_df))]

    with multiprocessing.Pool(processes=8) as pool:
        fao_overlaps_list = list(pool.starmap(fao_overlap_all,args))

    #Making a dataframe of overlaps
    fao_rhos = maps_df[['stockid']]
    fao_rhos['rhos'] = fao_overlaps_list
    for index, row in fao_rhos.iterrows():
        # Iterate over each element in the list
        for i, value in enumerate(row['rhos']):
            # Create new column 'rho_i' with value
            fao_rhos.at[index, f'rho_mpa_{i+1}'] = value

    #Exporting overlaps
    fao_rhos.drop('rhos', axis = 1).to_csv("data/intermediate/FAO_rhos.csv", mode = "w")
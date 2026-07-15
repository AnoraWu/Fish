#Importing packages
import multiprocessing
import rasterio
import rasterio.warp
from rasterio.plot import show
from rasterio.features import shapes
import os
import shapely as shp
import fiona
from fiona.transform import transform_geom
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

#os.environ['PROJ_LIB'] = "/Users/matthewneils/opt/anaconda3/envs/fish-env/share/proj/proj.db"
# os.chdir("")

def ram_overlap_one(RAM,MPA,ram_data,mpa_data):
    
    if ram_data.loc[ram_data["SP_ID"] == "%d" % (RAM)]['geometry'].is_empty.any():
        overlap = 999999
    
    else:
        ramrange = ram_data.loc[ram_data["SP_ID"] == "%d" % (RAM)].to_crs(crs="esri:54034")
        ramarea = ramrange.area.sum()
    
        if ramarea == 0:
            overlap = 999999
        
        else:
            mpaid = mpa_data.loc[mpa_data["NUM"] == MPA].to_crs(crs="esri:54034").buffer(0)
            if mpaid.empty:
                overlap = 999999
            else:
                mparange = gpd.GeoDataFrame(geometry=gpd.GeoSeries(mpaid))

                if ramrange.intersects(mparange, align = False).any():
                    # keep_geom_type=False because `keep_geom_type` does not support GeometryCollection, this will not affect the calculation of area
                    mpaoverlap = gpd.overlay(ramrange,mparange, how = "intersection", keep_geom_type=False)

                    if mpaoverlap['geometry'].is_valid.min() == False:
                        mpaoverlap['geometry'] = mpaoverlap['geometry'].buffer(0)
                        if mpaoverlap['geometry'].is_valid.min() == False:
                            print("Invalid mpa overlap")

                    mpaarea = mpaoverlap.area.sum()

                else:
                    mpaarea = 0
    
                overlap = mpaarea/ramarea
        
    return overlap

def ram_overlap_all(RAM, ram_data, mpa_data):
    list_ram = [RAM]*(len(mpa_data))
    datalist_ram = [ram_data]*(len(mpa_data))
    datalist_mpa = [mpa_data]*(len(mpa_data))

    ram_overlaps = map(ram_overlap_one, list_ram, range(1,len(mpa_data)+1), datalist_ram, datalist_mpa)
    
    return list(ram_overlaps)

if __name__ == "__main__":

    ###Bringing in Data
    ##Bringing in RAM stocks
    ram = gpd.read_file("data/raw/RAM Geography/results/ram.shp")

    #Bringing in RAM area names
    ids = pd.read_csv("data/raw/RAM Geography/sources/latlon.csv")

    #CSV contains area names in SP_ID order, but does not contain an SP_ID variable
    ids.insert(0, 'SP_ID', range(1, 233))
    ids['SP_ID'] = ids['SP_ID'].astype(str)

    ram = ram.merge(ids, on='SP_ID', how='left')
    ram = ram.set_crs('epsg:4326')

    #Fixing validity of RAM shapes (adding buffer(0))
    ram.loc[ram['geometry'].is_valid == False, 'geometry'] = ram.loc[ram['geometry'].is_valid == False, 'geometry'].buffer(0)

    #When reprojecting to cylindrical equal area, there is a known error that causes some shapes with extents near the bounding box to be distorted.
    #Clipping polygons to avoid this error, this will slightly reduce RAM ranges for 8 RAM areas
    ram[ram['geometry'].to_crs(crs="esri:54034").is_valid == False]=ram[ram['geometry'].to_crs(crs="esri:54034").is_valid == False].clip(shp.geometry.box(-180,-88,180,78))

    ##Bringing in FAO information
    fao = gpd.read_file("data/raw/FAO Geography/FAO_AREAS_CWP.shp")
    fao = fao[fao['F_LEVEL']== "MAJOR"]
    fao["NUM"] = fao.index

    ##Bringing in MPA Data
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

    mpa.insert(0,'NUM', range(1,176))

    #Fixing index
    mpa["Index"] = (mpa.loc[:,"NUM"] - 1)
    mpa.set_index("Index", inplace = True)
    mpa[['NUM', 'NAME', 'STATUS_YR', 'IUCN_CAT', 'WDPAID', 'geometry']].to_csv("data/intermediate/MPA.csv")

    #Running overlaps in parallel
    args = [(i, ram, mpa) for i in range(1, len(ram)+1)]

    with multiprocessing.Pool(processes=8) as pool:
        ram_overlaps_list = list(pool.starmap(ram_overlap_all,args))

    #Converting to dataframe
    colnames = [f'rho_mpa_{i}' for i in range(1, len(mpa)+1)]
    ram_overlaps_df_pll = pd.DataFrame(ram_overlaps_list, columns = colnames) 
    ram_overlaps_df_pll.replace(999999,np.nan,inplace=True)

    #Combining into ram dataframe and saving
    ram = ram.merge(ram_overlaps_df_pll, left_index=True, right_index=True)
    ram.to_csv("data/intermediate/RAM_rhos.csv")

    ###Determining majority FAO area for RAMs (for ML Model)
    FAOs = {}
    for x in range(0,len(fao)):
        faoinf = fao[fao["NUM"] == x]
        FAOs[x] = faoinf

    RAMs = {}
    for x in range(1, len(ram)+1):
        raminf = ram[ram["SP_ID"] == "%d" % (x)]
        RAMs[x] = raminf

    #For each RAM area, determining the FAO area that the majority of the RAM area is in           
    ram_fao = {}
    for x in range(1,len(ram)+1):
        ram_check = RAMs[x]
        fao_overlap = {}
        for y in range (0,len(fao)):
            fao_check = FAOs[y]
            if ram_check.intersects(fao_check, align = False).any():
                overlaps = gpd.overlay(fao_check.to_crs('EPSG:4326'),ram_check.to_crs('EPSG:4326'),how = 'intersection',keep_geom_type=False)
                fao_overlap[y] = overlaps.to_crs(crs="esri:54034").buffer(0).area.loc[0] / 10**6
            else:
                fao_overlap[y] = 0
                
        if max(fao_overlap.values()) == 0:
            ram_fao[x] = "Nowhere"
        else:
            ram_fao[x] = fao.loc[max(fao_overlap, key = lambda k: fao_overlap[k]),"NAME_EN"]

    #Exporting RAM-FAO crosswalk
    ram["FAO_AREA"] = ram["SP_ID"].astype(int).map(ram_fao)
    RAM_FAO = ram[["SP_ID","name","FAO_AREA"]].copy()
    RAM_FAO.to_stata("data/intermediate/RAM_FAO.dta")
# setup -------------------------------------------------------------------

#Activate and restore the renv environment
if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv", quiet = TRUE)
}

if (file.exists("renv/activate.R")) {
  source("renv/activate.R")
} else {
  stop("renv environment not found. Please initialize renv first.")
}
renv::restore()

#Activate GPG
os <- .Platform$OS.type
if (os == "windows") {
  new_path <- "C:/Program Files (x86)/GnuPG/bin;C:/Program Files/Git/usr/bin;C:/Program Files/Git/bin"
} else {
  new_path <- "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
}
Sys.setenv(PATH = new_path)
gpg_path <- Sys.which("gpg")
if (gpg_path != "") {
  Sys.setenv(GPG_PATH = gpg_path) 
} else {
  stop("Error: GPG not found. Please install GPG or specify the correct path.")
}
system2(Sys.getenv("GPG_PATH"), "--version", stdout = TRUE, stderr = TRUE)

#Set output path
output_dir <- "data/intermediate/Stock Geography/"
if (!dir.exists(output_dir)) {
  dir.create(output_dir)
}


library(rcrypt)
library(aquamapsdata)
library(dplyr)
library(leaflet)
library(raster)
library(sf)
library(terra)
library(feather)
library(readr)
library(haven)

#Only need to run download_db() the first time on each machine.
try(download_db())
default_db("sqlite")

fao_data <- haven::read_dta("data/intermediate/FAO_country_wide_GLOBAL.dta")

##Testing with Cod

#get the unique species identifier 
cod_id <- am_search_fuzzy(search_term = "Gadus morhua")%>% pull(key)
#get the species data using its identifier
cod_data <- am_search_exact(SpeciesID = cod_id)
#convert in raster format
exras <- am_raster(cod_id)
#create a leaflet map
am_map_leaflet(exras, title = "Gadus morhua")

#making a polygon of only cells with values > 0.5
exras[exras[] <= 0.5] <- NA

exras <- rast(exras)

#creates a polygon that represents the bounding box of the raster.
pe <- as.polygons(ext(exras))
#creates a polygon that represents the boundary of exras
pr <- as.polygons(exras > -Inf)

plot(exras)
plot(pe, lwd=5, border='red', add=TRUE)
plot(pr, lwd=1, border='blue', add=TRUE)

names(exras) <- paste0("cod","test")

#Now looping through all relevant stocks. 
stocks <- unique(fao_data$scientific_name)
#Dropping empty stock name
stocks <- stocks[nzchar(stocks)]

#Initializing list for storing
mapspoly <- vector('list', length(stocks))
maps <- vector('list', length(stocks))
i <- 0

for (x in stocks){
  
  i = i + 1
  
  #If there is a comma or parentheses (due to alternative names), keeping only the first listed name
  x <- gsub("^(.*?),.*", "\\1", x)
  x <- gsub("\\..*", "", x)
  x <- trimws(x, whitespace = "\\s*\\(.*")
  
  stock_map_id <- am_search_fuzzy(x) %>% pull(key)
  
  if (length(stock_map_id) == 0){
    print(paste("No map for",x))
    next
  }
  
  ras <- am_raster(stock_map_id)
  crs(ras) <- "EPSG:4326"
  #Keeping only cells with values > 0.5
  ras[ras[] <= 0.5] <- NA
  ras <- rast(ras)
  
  pr <- as.polygons(ras > -Inf)
  
  maps[[i]] <- ras
  mapspoly[[i]] <- pr
  
  names(maps)[i] <- x
  names(mapspoly)[i] <- x
  
  print(x)
}

#Saving rasters individually.
#Would prefer to save them together, but cannot find a reasonable way.
for (i in 1:length(maps)){
  
  if (is.na(names(maps)[[i]])){
    next
  }
  
  writeRaster(maps[[i]], paste0(paste0("data/intermediate/Stock Geography/StockMap_", i),".tif"), overwrite = TRUE)
  
}

#Saving ordered list of names to identify the stock maps
stocknames <- data.frame(
  name = stocks
)

write_csv(stocknames, "data/intermediate/Stock Geography/StockNames.csv")
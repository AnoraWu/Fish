# setup -------------------------------------------------------------------


#Bringing in Fishlife Package
library(utils)
library(readr)
library(devtools)
devtools::install_github("james-thorson/FishLife@2.0.1", upgrade = "never")
library(FishLife)

#Generating predicted values
predictions <- FishBase_and_RAM
#beta_gv: predictive mean (in transformed space) among traits for every taxon in tree
output <- predictions[["beta_gv"]] 
names <- rownames(output)

#Exporting predictions
output_df <- as.data.frame(output, row.names = names)
output_df$v1 <- names
write_csv(output_df,"data/raw/fishlife.csv")


# setup -------------------------------------------------------------------
if (file.exists("renv/activate.R")) {
  source("renv/activate.R")
} else {
  stop("renv environment not found. Please initialize renv first.")
}
renv::restore()

library(tidyverse)

library(taxize)

library(countrycode)

library(glue)

library(dbplyr)

library(ggplot2)

library(sraplus)

library(vip)

library(ramlegacy)

library(ranger)

library(xgboost)

library(tidymodels)

library(foreach)

library(doParallel)

library(ggtext)

library(FishLife)

library(gt)

library(patchwork)

library(remotes)

here::i_am("code/FAO predictions/FAO_Predictions.R")

tune_com <- TRUE

run_loo <- TRUE

functions <- list.files(here::here("code/FAO predictions/R"))

purrr::walk(functions, ~ source(here::here("code/FAO predictions/R", .x)))

##### set options #####

results_path <- here::here("result")

results_name <- "FAO Predictions"

results_description <-
  "testing"

write(results_description,
      file = here::here("data/raw", results_name, "description.txt"))

cores <- 8

seednum <- 8592

get_ram_data <- TRUE #organize RAM data

min_years_catch <- 25 # minimum years of catch data to include

crazy_b <- 5 # maximum B/Bmsy to allow

crazy_u <-10 # maximum U/Umsy to allow

catchability <- 1e-3 # survey catchability

plot_theme <- theme_minimal(base_size = 14)

theme_set(plot_theme)

set.seed(seednum)

#get fao data -------------------------------------------------------------

fao.data <- haven::read_dta(here::here("data/intermediate/FAO_Pred_Prep_GLOBAL.dta"))
fao.data <- fao.data %>%
  filter(num_years >= 25) %>%
  group_by(stockid) %>%
  filter(max(landings) > 0) %>%
  ungroup()

# get ram data ------------------------------------------------------------

if (get_ram_data) {
  load(here::here("data/raw/RAMLDB v4/R Data/DBdata[asmt][v4.495].RData"))
  
  # process ram data ------------------------------------------------------------
  
  stock <- stock %>%
    left_join(area, by = "areaid")
  # catches
  ram_catches <- tcbest.data %>%
    mutate(year = rownames(.) %>% as.integer()) %>%
    as_tibble() %>%
    gather(stockid, catch, -year)
  
  # B/Bmsy
  ram_b_v_bmsy <- divbpref.data %>%
    mutate(year = rownames(.) %>% as.integer()) %>%
    tibble() %>%
    gather(stockid, b_v_bmsy, -year)
  
  # U/Umsy
  ram_u_v_umsy <- divupref.data %>%
    mutate(year = rownames(.) %>% as.integer()) %>%
    as_tibble() %>%
    gather(stockid, u_v_umsy, -year)
  
  # Effort
  ram_effort <- effort.data %>%
    mutate(year = rownames(.) %>% as.integer()) %>%
    as_tibble() %>%
    gather(stockid, effort, -year)
  
  # biomass
  
  ram_total_biomass <- tbbest.data %>%
    mutate(year = rownames(.) %>% as.integer()) %>%
    as_tibble() %>%
    gather(stockid, total_biomass, -year)
  
  # ssb
  
  ram_ss_biomass <- ssb.data %>%
    mutate(year = rownames(.) %>% as.integer()) %>%
    as_tibble() %>%
    gather(stockid, ss_biomass, -year)
  
  
  ram_exp_rate <- ram_catches %>%
    left_join(ram_total_biomass, by = c("stockid", "year")) %>%
    mutate(exploitation_rate = catch / total_biomass) %>%
    dplyr::select(-catch,-total_biomass)
  
  # put it together
  
  ram_data <- ram_catches %>%
    left_join(bioparams_values_views, by = "stockid") %>%
    left_join(ram_b_v_bmsy, by = c("stockid", "year")) %>%
    left_join(ram_u_v_umsy, by = c("stockid", "year")) %>%
    left_join(ram_exp_rate, by = c("stockid", "year")) %>%
    left_join(ram_effort, by = c("stockid", "year")) %>%
    left_join(ram_total_biomass, by = c("stockid", "year")) %>%
    left_join(ram_ss_biomass, by = c("stockid", "year")) %>%
    left_join(stock, by = "stockid") %>%
    dplyr::select(stockid, scientificname, commonname, everything())
  
  
  # create new variables
  
  ram_data <- ram_data %>%
    mutate(tb_v_tb0 = total_biomass / TB0,
           ssb_v_ssb0 = ss_biomass / SSB0)
  
  # filter data -------------------------------------------------------------
  
  # for now, only include continuous catch series
  
  ram_data <- ram_data %>%
    filter(is.na(catch) == FALSE) %>%
    # filter(stockid == "ATBTUNAEATL") %>%
    group_by(stockid) %>%
    mutate(delta_year = year - lag(year)) %>%
    mutate(delta_year = case_when(year == min(year) ~ as.integer(1),
                                  TRUE ~ delta_year)) %>%
    mutate(missing_gaps = any(delta_year > 1)) %>%
    filter(missing_gaps == FALSE) %>%
    mutate(n_years = n_distinct(year)) %>%
    filter(n_years >= min_years_catch) %>%
    filter(all(b_v_bmsy < crazy_b, na.rm = TRUE),
           all(u_v_umsy < crazy_u, na.rm = TRUE)) %>%
    ungroup() %>%
    group_by(stockid) %>%
    mutate(
      has_tb0 = !all(is.na(TB0)),
      has_tb = all(!is.na(total_biomass)),
      first_catch_year = year[which(catch > 0)[1]]
    ) %>%
    filter(year >= first_catch_year) %>%
    mutate(
      pchange_effort = lead(u_v_umsy) / (u_v_umsy + 1e-6),
      cs_effort = (u_v_umsy - mean(u_v_umsy)) / sd(u_v_umsy),
      index = total_biomass * catchability,
      approx_cpue = catch / (u_v_umsy / catchability + 1e-3),
      b_rel = dplyr::case_when(
        has_tb0 ~ total_biomass / max(TB0),
        has_tb ~ total_biomass / max(total_biomass),
        TRUE ~ b_v_bmsy / 2.5
      )
    ) %>%
    mutate(approx_cpue = pmin(quantile(approx_cpue, 0.9, na.rm = TRUE), approx_cpue)) %>%
    ungroup()
  
  dir.create(here::here("data"), showWarnings = FALSE)
  dir.create(here::here("data", "ram"), showWarnings = FALSE)
  write_rds(ram_data, file = here::here("data", "ram", "ram-data.rds"))
  
} else {
  ram_data <- read_rds(file = here("data", "ram", "ram-data.rds"))
  
}



ram_data <- ram_data %>%
  rename(
    fao_area_code = primary_FAOarea,
    scientific_name = scientificname,
    common_name = commonname,
    capture = catch
  ) %>%
  mutate(
    macroid = paste(scientific_name, fao_area_code, sep = '_'),
    fao_area_code = as.integer(fao_area_code)
  )

ram_stocks <- ram_data %>%
  dplyr::select(scientific_name, common_name, fao_area_code, macroid) %>%
  unique()

# train machine learning model to predict catches -------------------------

# classify stocks by stock history shape

ram_catches <- ram_data %>%
  mutate(catch = capture) %>%
  ungroup() %>%
  dplyr::select(stockid, year, catch) %>%
  group_by(stockid) %>%
  mutate(stock_year = 1:length(catch),
         n_years = length(catch)) %>%
  mutate(scaled_catch = scale(catch)) %>%
  ungroup() %>%
  filter(n_years > 25,
         stock_year <= 25) %>%
  mutate(type = "ram")

fao_catches <- fao.data %>%
  mutate(catch = landings) %>%
  ungroup() %>%
  dplyr::select(stockid, catch, year) %>%
  group_by(stockid) %>%
  mutate(stock_year = 1:length(catch),
         n_years = length(catch)) %>%
  mutate(scaled_catch = scale(catch)) %>%
  filter(is.nan(scaled_catch) == FALSE) %>%
  ungroup() %>%
  filter(n_years > 25,
         stock_year <= 25) %>%
  mutate(type = "fao")

all_catches <- rbind(ram_catches, fao_catches)

all_catches %>%
  ggplot(aes(stock_year, scaled_catch, color = stockid)) +
  geom_line(show.legend = FALSE)

all_catches <- all_catches %>%
  dplyr::select(stockid, stock_year, scaled_catch) %>%
  pivot_wider(names_from = stock_year, values_from = scaled_catch) %>%
  ungroup()

nstocks <- nrow(all_catches)

map_dbl(all_catches, ~ sum(is.na(.x)))

a = all_catches %>% dplyr::select(-stockid) %>% as.matrix()
set.seed(42)
catch_pca <- kernlab::specc(a, centers = 4)

# centers(catch_pca)
# size(catch_pca)
# withinss(catch_pca)

cluster <- as.vector(catch_pca)

all_catches$cluster <- cluster

all_catches <- all_catches  %>%
  pivot_longer(c(-stockid,-cluster),
               names_to = "stock_year",
               values_to = "catch",) %>%
  mutate(stock_year = as.integer(stock_year))

cluster_plot <- all_catches %>%
  ggplot(aes(stock_year, catch, group = stockid)) +
  geom_line(alpha = 0.1) +
  facet_wrap( ~ cluster) +
  scale_x_continuous(name = "Stock Year") +
  scale_y_continuous(name = "Centered and Scaled Catches") +
  theme_minimal()

ggsave(filename = file.path(results_path,"all_clusters.png"),cluster_plot, width = 180,height = 120, units = "mm")

cluster_data <- all_catches %>%
  pivot_wider(names_from = stock_year, values_from = catch) %>%
  ungroup() %>%
  mutate(cluster = as.factor(cluster)) %>%
  janitor::clean_names()

cluster_splits <-
  rsample::initial_split(cluster_data, strata = cluster)


cluster_model <-
  rand_forest(mtry = tune(),
              min_n = tune(),
              trees = 1000) %>%
  set_engine("ranger", num.threads = 8) %>%
  set_mode("classification")


cluster_recipe <-
  recipes::recipe(cluster ~ ., data = training(cluster_splits) %>% dplyr::select(-stockid)) %>%
  themis::step_upsample(cluster)

cluster_workflow <-
  workflows::workflow() %>%
  workflows::add_model(cluster_model) %>%
  workflows::add_recipe(cluster_recipe)

val_set <- training(cluster_splits) %>% dplyr::select(-stockid) %>%
  rsample::vfold_cv()

set.seed(345)
cluster_tuning <-
  cluster_workflow %>%
  tune_grid(
    val_set,
    grid = 20,
    control = control_grid(save_pred = TRUE),
    metrics = metric_set(roc_auc)
  )


best_forest <- cluster_tuning %>%
  select_best("roc_auc")

final_workflow <-
  cluster_workflow %>%
  finalize_workflow(best_forest)

cluster_fit <-
  final_workflow %>%
  fit(data = training(cluster_splits) %>% dplyr::select(-stockid))

cluster_fit <- workflows::extract_fit_parsnip(cluster_fit)

training_data <- training(cluster_splits) %>%
  bind_cols(predict(cluster_fit, new_data = .)) %>%
  mutate(split = "training")

testing_data <- testing(cluster_splits) %>%
  bind_cols(predict(cluster_fit, new_data = .)) %>%
  mutate(split = "testing")

cluster_predictions <- training_data %>%
  bind_rows(testing_data) %>%
  rename(predicted_cluster = .pred_class)

cluster_model_performance <- cluster_predictions %>%
  group_by(split, cluster) %>%
  summarise(accuracy = mean(cluster == predicted_cluster))

cluster_model_performance %>%
  ggplot(aes(cluster, accuracy, fill = split)) +
  geom_col(position = "dodge")

cluster_predictions %>%
  group_by(split) %>%
  summarise(accuracy = mean(cluster == predicted_cluster)) %>%
  pivot_wider(names_from = "split", values_from = "accuracy") %>%
  mutate(testing_loss = testing / training - 1)

status_model_data <- ram_data %>%
  mutate(catch = capture) %>%
  filter(stockid %in% unique(cluster_predictions$stockid)) %>%
  left_join(cluster_predictions %>% dplyr::select(stockid, predicted_cluster),
            by = "stockid") %>%
  left_join(
    sraplus::fao_taxa$fao_species %>% dplyr::select(scientific_name, isscaap_group),
    by = c("scientific_name" = "scientific_name")
  ) %>%
  group_by(stockid) %>%
  mutate(
    c_div_maxc = catch / max(catch, na.rm = TRUE),
    c_div_meanc = catch / mean(catch, na.rm = TRUE),
    fishery_year = 1:length(catch)
  ) %>%
  mutate(
    c_roll_meanc = RcppRoll::roll_meanr(c_div_meanc, 5),
    c_roll_maxc = catch / cummax(catch),
    c_init_slope = lm(log(catch[1:10] + 1e-3) ~ year[1:10])$coefficients[2]
  ) %>%
  gather(metric, value, b_v_bmsy, u_v_umsy, exploitation_rate) %>%
  dplyr::select(stockid,
         year,
         contains('c_'),
         metric,
         value,
         predicted_cluster,
         fishery_year) %>%
  mutate(log_value = log(value + 1e-3)) %>%
  unique() %>%
  na.omit() %>%
  ungroup() %>%
  group_by(stockid) %>%
  filter(fishery_year > 20) %>%
  ungroup()

fao_status_model_data <- fao.data %>%
  filter(fishery_year >= 20) %>%
  rename(catch = landings) %>%
  rename(scientific_name = scientificname) %>%
  filter(stockid %in% unique(cluster_predictions$stockid)) %>%
  left_join(cluster_predictions %>% dplyr::select(stockid, predicted_cluster),
            by = "stockid") %>%
  group_by(stockid) %>%
  mutate(c_init_slope = lm(log(catch[1:10] + 1e-3) ~ year[1:10])$coefficients[2]) %>%
  filter(fishery_year > 20) %>%
  ungroup()
# OK now have dataframe ready to make predictions of stock status based on catch

# add in life history data

lh <- haven::read_dta(here::here("data/intermediate/life_history.dta")) %>%
  mutate(m_v_k = exp(m) / exp(k),
         linf_v_lmat = exp(ln_loo) / exp(lm)) %>%
  rename("scientific_name" = "scientificname")

b_data <- status_model_data %>%
  filter(metric == "b_v_bmsy") %>%
  left_join(ram_data %>% dplyr::select(stockid, primary_country, fao_area_code) %>% unique(),
            by = "stockid") %>%
  left_join(lh, by = "scientific_name") %>%
  drop_na("ln_loo")

fao_b_data <- fao_status_model_data %>%
  drop_na("ln_loo")

b_data %>%
  group_by(stockid) %>%
  # filter(fishery_year == max(fishery_year)) %>%
  ungroup() %>%
  ggplot(aes(ln_fmsy, value)) +
  geom_point() +
  geom_smooth(method = "lm") +
  scale_y_continuous(name = "Recent B/Bmsy") +
  facet_wrap( ~ predicted_cluster)

# b_data %>%
#   group_by(stockid) %>%
#   filter(fishery_year == max(fishery_year)) %>%
#   ungroup() %>%
#   ggplot(aes(m_v_k, value)) +
#   geom_point() +
#   geom_smooth(method = "lm") +
#   scale_y_continuous(name = "Recent B/Bmsy") +
#   facet_wrap(~predicted_cluster)

# generate splits
#

training_data <- b_data

testing_data <- fao_b_data

analysis_data <- training_data %>%
  rsample::group_vfold_cv(group = "fao_area_code")


analysis_data <- training_data %>%
  rsample::group_vfold_cv(group = "stockid", v = 5)

# prepare model workflow

# com_model <-
#   parsnip::rand_forest(
#     mode = "regression",
#     mtry = tune(),
#     min_n = tune(),
#     trees = 500
#   ) %>%
#   parsnip::set_engine("ranger")
#
# com_workflow <- workflow() %>%
#   add_model(com_model) %>%
#   add_formula(
#      value ~ c_div_maxc + c_div_meanc + c_length + c_roll_meanc + c_roll_maxc + c_init_slope + predicted_cluster + fishery_year + loo + linf_v_lmat + winfinity + tmax + tm + lm + temperature + ln_var + rho +
#       ln_masps + ln_margsd + h + logitbound_h + ln_fmsy_over_m + ln_fmsy + ln_r + ln_g + m_v_k
#   )

tune_grid <-
  parameters(
    min_n(range(2, 10)),
    tree_depth(range(2, 15)),
    learn_rate(range = c(-3,-.25)),
    mtry(),
    loss_reduction(),
    sample_prop(range = c(0.25, 1)),
    trees(range = c(10, 750))
  ) %>%
  dials::finalize(mtry(), x = training_data %>% dplyr::select(-(1:2)))

xgboost_grid <- grid_latin_hypercube(tune_grid, size = 40)
xgboost_grid$learn_rate %>% hist()
xgboost_model <-
  parsnip::boost_tree(
    mode = "regression",
    mtry = tune(),
    min_n = tune(),
    loss_reduction = tune(),
    sample_size = tune(),
    learn_rate = tune(),
    tree_depth = tune(),
    trees = tune()
  ) %>%
  parsnip::set_engine("xgboost")

xgboost_workflow <- workflow() %>%
  add_model(xgboost_model) %>%
  add_formula(
    value ~ c_div_maxc + c_div_meanc + c_roll_meanc + c_roll_maxc + c_init_slope + predicted_cluster + fishery_year + ln_loo + linf_v_lmat + ln_winfinity  + ln_var + h + ln_fmsy_over_m + m_v_k
  )

# xgboost_workflow <- workflow() %>%
#   add_model(xgboost_model) %>%
#   add_formula(
#     value ~ c_div_maxc + c_div_meanc + c_roll_meanc + c_roll_maxc + c_init_slope + predicted_cluster + fishery_year)

if (tune_com) {
  workers <- 4 
  
  cl <- makePSOCKcluster(workers)
  #
  registerDoParallel(cl)
  #
  getDoParName()
  #
  getDoParWorkers()
  # #
  a <- Sys.time()
  
  dir.create(here("intermediate"), showWarnings = FALSE)
  
  xgboost_tuning <- tune_grid(
    xgboost_workflow,
    resamples = analysis_data,
    grid = xgboost_grid,
    control = control_grid(save_pred = FALSE)
  ) 
  
  Sys.time() - a
  
  
  write_rds(xgboost_tuning, file = here("intermediate","com_tunegrid.rds"))
  
  #write_rds(com_tunegrid, file = "com_tunegrid.rds")
  
} else {
  
  xgboost_tuning <- readr::read_rds(here("intermediate","com_tunegrid.rds"))
  
}

tuning_plot =autoplot(xgboost_tuning, metric = "rmse") +
  scale_y_continuous(limits = c(NA, 1))

best_vals <- tune::select_best(xgboost_tuning, metric = "rmse")

# best_vals$trees <- 300

com_workflow <- finalize_workflow(xgboost_workflow,
                                  best_vals)

# finalize model

com_model <- com_workflow %>%
  fit(data = training_data)

vip(com_model$fit$fit$fit)

vi_values <- vi(com_model$fit$fit$fit)


bad_var_name <-
  c(
    "c_roll_maxc",
    "m_v_k",
    "c_div_maxc" ,
    "predicted_cluster4",
    "c_init_slope",
    "ln_var",
    "c_roll_meanc" ,
    "h"    ,
    "ln_fmsy_over_m",
    "linf_v_lmat"  ,
    "fishery_year",
    "c_div_meanc",
    "ln_winfinity",
    "ln_loo",
    "predicted_cluster3",
    "predicted_cluster1"
  )

good_var_name <-
  c(
    "Catch divided by rolling max catch",
    "Natural mortality divided by Von Bertalanffy growth coefficient",
    "Catch divided by maximum catch",
    "Predicted catch cluster = 4",
    "Initial log slope of the catch",
    "Estimate of recruitment process error",
    "Catch divided by rolling mean catch",
    "Steepness",
    "Log of Fmsy divided by natural mortality",
    "Von Bertalanffy asymptotic length divided by length at maturity",
    "Sequential fishery year",
    "Catch divided by mean catch",
    "Asymptotic weight",
    "Asymptotic length",
    "Predicted catch cluster = 3",
    "Predicted catch cluster = 1"
  )

vi_names <- tibble(Variable = vi_values$Variable,name = good_var_name)

vi_table <- vi_values %>%
  left_join(vi_names, by = "Variable") %>%
  dplyr::select(-Variable) %>%
  rename(Variable = name) %>%
  mutate(Importance = round(Importance,2)) %>%
  dplyr::select(Variable, Importance)

knitr::kable(vi_table, format = "latex", booktabs = TRUE)

# fit to FAO data

fao_predicted <- testing_data %>%
  cbind(predict(com_model, new_data =  testing_data)) %>%
  rename(b_ratio = .pred)

write_csv(fao_predicted, here::here("data/intermediate/SRAPriors.csv"))

# applying SRAplus to FAO stocks using predicted priors
#Bringing in resilience
fao_resilience <- read_csv(here::here("data/raw/Fao_Resilience"))

fao_sraplus <- fao_predicted %>%
  dplyr::select(stockid, scientific_name, fishery_year, b_ratio) %>%
  left_join(fao.data %>% dplyr::select(stockid, landings, fishery_year, year, isscaap) %>% unique(),
            by = c("stockid","fishery_year")) %>%
  left_join(fao_resilience %>% rename(scientific_name = species), 
            by = c("scientific_name"))

fao_sraplus["resilience"][is.na(fao_sraplus["resilience"])] <- "Medium"

fao_sraplus <- fao_sraplus %>%
  group_by(stockid) %>%
  mutate(max_year = max(fishery_year), min_year = min(fishery_year))

stocks <- unique(fao_sraplus$stockid)

#Creating an empty dataframe to append results to
allresults <- data.frame(matrix(ncol = 1, nrow = 0))

for (x in stocks){
  
  stockdata <- fao_sraplus[fao_sraplus$stockid == x,]
  stockdata <- stockdata[order(stockdata$fishery_year),]
  
  startyear = min(stockdata$fishery_year)
  endyear = max(stockdata$fishery_year)
  
  start_b = max(stockdata[stockdata$fishery_year == startyear, 'b_ratio'])
  end_b = max(stockdata[stockdata$fishery_year == endyear, 'b_ratio'])
  
  scientificname = unique(stockdata$scientific_name)
  isscaap = max(stockdata$isscaap)
  
  catchdata <- fao.data[fao.data$stockid == x,] %>% 
    dplyr::select(stockid, year, landings) 
  catchdata <- catchdata[order(catchdata$year),]
  
  if(nrow(catchdata) == 0){
    next
  }
  
  if(unique(stockdata$resilience) == "Very Low"){
    growth = 0.025
    grange = 0.99
  } else if(unique(stockdata$resilience) == "Low"){
    growth = 0.1
    grange = 0.5
  } else if(unique(stockdata$resilience) == "Medium"){
    growth = 0.325
    grange = 0.538
  } else if(unique(stockdata$resilience) == "High"){
    growth = 0.75
    grange = 0.333
  } else{
    growth = 0.325
    grange = 0.538
  }
  
  fao_driors <- format_driors(
    initial_state = 2.5,
    initial_state_cv = 0.05,
    taxa = scientificname,
    terminal_state = end_b,
    terminal_state_cv = 0.2,
    catch = catchdata$landings,
    years = catchdata$year,
    growth_rate_prior = growth,
    growth_rate_prior_cv = grange,
    b_ref_type = "b",
    m = 1.01,
    isscaap_group = isscaap
  )
  
  fao_fit <- fit_sraplus(
    driors = fao_driors,
    engine = "sir",
    draws = 1e6,
    n_keep = 4000,
    estimate_shape = TRUE,
    estimate_proc_error = TRUE
  )
  
  results <- fao_fit$results
  
  k <- max(results[results$variable == 'k', 'mean'])
  msy <- max(results[results$variable == 'msy', 'mean'])
  g <- max(results[results$variable == 'r', 'mean'])
  g_sd <- (max(results[results$variable == 'r', 'sd']))
  
  b_results <- results[results$variable == 'b_div_bmsy',] %>%
    dplyr::select(year, mean) %>%
    pivot_wider(names_from = 'year', values_from = 'mean') 
  colnames(b_results) <- paste(colnames(b_results),"bratio",sep="_")
  
  f_results <- results[results$variable == 'u_div_umsy',] %>%
    dplyr::select(year, mean) %>%
    pivot_wider(names_from = 'year', values_from = 'mean') 
  colnames(f_results) <- paste(colnames(f_results),"fratio",sep="_")
  
  stockresults <- cbind(b_results,f_results) %>%
    mutate(stockid = x) %>%
    mutate(k = k) %>%
    mutate(msy = msy) %>%
    mutate(g = g) %>%
    mutate(g_sd=g_sd)
  
  allresults <- bind_rows(allresults, stockresults)
  
  print(x) 
}

names(allresults) <- sub("^(.*)_(.*)$", "\\2_\\1", names(allresults))

write_csv(allresults, here::here("data/intermediate/FAO_Pred_Results.csv"))
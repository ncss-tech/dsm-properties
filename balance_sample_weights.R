
library(sf)
library(raster)
library(ggplot2)
library(dplyr)


setwd("G:/100m_covariates")


# load pedons
pts <- readRDS("CONUS_nasis_SSURGO_SG100_covarsc.rds")
pts <- st_as_sf(pts,
                coords = c("x", "y"),
                crs = 5070
)


# load rasters
lf <- list.files("G:/100m_covariates", pattern = ".tif$", full.names = TRUE)

vars_l <- list(
  # DEM = "DEMNED6",
  SLOPE = "SLPNED6",
  POS   = "POSNED6",
  # NLCD  = "NLCD116",
  # PM    = "PMTGSS7",
  EVI   = paste0("EX", 1:6, "MOD5"),
  PPT   = paste0("P",  formatC(1:12, width = 2, flag = "0"), "PRI5"),
  TEMP  = paste0("T",  formatC(1:12, width = 2, flag = "0"), "PRI5") 
)
vars <- paste0("G:/100m_covariates/", unlist(vars_l), ".tif")
# pat <- paste(vars, collapse = "|")
rs <- stack(vars[-9]) #, function(x) raster(x))


# sample rasters
set.seed(42)
npixels <- 1563535900
# npixels <- 10000
samp <- st_sample(read_sf(dsn = "D:/geodata/soils/SSURGO_CONUS_FY19.gdb", layer = "SAPOLYGON"), size = floor(npixels * 0.001), type = "random")
# samp <- as(samp, "Spatial")
# saveRDS(samp, file = "samp_random.RDS")
samp <- readRDS(file = "samp_random.RDS")


# # parallelized extract: (larger datasets)
# samp2 <- as(samp, "Spatial")
# 
# beginCluster(type='SOCK')
# cl <- getCluster()
# parallel::clusterExport(cl, "samp2")
# clusterR(rs, extract, args = list(y = samp2), progress = TRUE)
# endCluster()
# 
# 
# library(snowfall)
# 
# cpus <- parallel::detectCores(all.tests = FALSE, logical = TRUE) - 1
# sfInit(parallel = TRUE, cpus = cpus)
# sfExport("samp2", "vars")
# sfLibrary(raster)
# sfLibrary(rgdal)
# Sys.time()
# samp_ex <- sfLapply(vars, function(i){ try(raster::extract(raster(i), samp2))})
# Sys.time()
# snowfall::sfStop()


# terra extract
library(terra)

samp_xy <- st_coordinates(samp)
samp_xy <- samp_xy[sample(1:nrow(samp_xy), 1000), ]
samp_v <- vect(samp_xy)
crs(samp_v) <- "+init=epsg:5070"

rs <- rast(vars[-9])
Sys.time()
rs_s <- extract(rs, samp_v)
Sys.time()
# saveRDS(rs_s, file = "rs_sample.RDS")
ref_df <- readRDS(file = "rs_sample.RDS")



# # exactextractr extract
# library(exactextractr)
# 
# pts <- samp %>%
#   slice(sample(1:nrow(samp_xy), 1000))
#   st_buffer(dist = 0.1) %>%
#   st_cast("POLYGON")
# test <- exact_extract(rs, pts, "mean")


# transform pts and rasters
obs_df <- as.data.frame(pts)
ppt_idx  <- names(obs_df) %in% vars_l$PPT[-1]
temp_idx <- names(obs_df) %in% vars_l$TEMP
evi_idx  <- names(obs_df) %in% vars_l$EVI
obs_df$PPT  <- apply(obs_df[ppt_idx],  1, sum,  na.rm = TRUE)
obs_df$TEMP <- apply(obs_df[temp_idx], 1, mean, na.rm = TRUE)
obs_df$EVI  <- apply(obs_df[evi_idx],  1, mean, na.rm = TRUE)
# obs_df$PM   <- as.factor(obs_df$PMTGSS7)


ppt_idx   <- names(ref_df) %in% vars_l$PPT[-1]
temp_idx  <- names(ref_df) %in% vars_l$TEMP
evi_idx   <- names(ref_df) %in% vars_l$EVI
ref_df$PPT  <- apply(ref_df[ppt_idx],  1, sum, na.rm = TRUE)
ref_df$TEMP <- apply(ref_df[temp_idx], 1, mean, na.rm = TRUE)
ref_df$EVI  <- apply(ref_df[evi_idx],  1, mean, na.rm = TRUE)
# ref_df$PM <- as.factor(ref_df$PMTGSS7)
# ref_df$NLCD <- as.factor(ref_df$NLCD116)



# tabulate raster
vars <- c("SLPNED6", "POSNED6", "EVI", "PPT", "TEMP")
p1 <- seq(0, 1, 0.1)
p2 <- seq(0, 1, 0.5)
probs <- list(p1, p2, p1, p1, p1)
names(probs) <- vars



# function to balance weights
bw <- function(ref_df, obs_df, vars, probs) {
  
  # tidy variables
  ref_df <- ref_df[vars]
  obs_df <- obs_df[vars]
  
  
  # count inputs
  n_ref   <- ncol(ref_df)
  n_obs   <- ncol(obs_df)
  n_vars  <- length(vars)
  
  if (!is.list(probs)) {
    probs <- list(probs)[rep(1, n_ref)]
    n_probs <- n_ref
  } else n_probs <- length(probs)
  
  
  # add id
  ref_df$id <- 1:nrow(ref_df)
  obs_df$id <- 1:nrow(obs_df)
  
  
  # check
  test <- all.equal(n_ref, n_obs, n_vars, n_probs)
  if (!test) stop("ref_df and obs_df must contain all vars and be the same length")
  
  
  # tabulate ref
  brks <- lapply(vars, function(x) {
    quantile(ref_df[, x], probs = probs[[x]], na.rm = TRUE)
    })
  names(brks) <- vars
  
  ref_brks <- ref_df
  ref_brks[1:n_ref] <- lapply(vars, function(x) {
    brks <- quantile(ref_df[x], probs = probs[[x]], na.rm = TRUE)
    as.integer(cut(ref_df[, x], breaks = unique(brks), include.lowest = TRUE))
    })
  ref_brks$source <- "ref"
  ref_brks[1:n_ref] <- lapply(vars, function(x) {
    formatC(ref_brks[, x], width = 2, flag = "0")
  })
  ref_brks$interval <- apply(ref_brks[vars], 1, paste0, collapse = "-")
  
  ref_pct <- lapply("interval", function(x) {
    temp           <- round(prop.table(table(ref_brks[x])) * 100, 4)
    temp           <- as.data.frame.table(temp)
    temp$Var1      <- as.character(temp$Var1)
    names(temp)[1] <- "interval"
    temp$var <- x
    temp$source <- "ref"
    return(temp)
    })
  ref_pct <- do.call("rbind", ref_pct)
  
  
  
  # tabulate obs
  obs_brks <- obs_df
  obs_brks[1:n_obs] <- lapply(vars, function(x) {
    as.integer(cut(obs_df[, x], breaks = unique(brks[[x]]), include.lowest = TRUE))
  })
  obs_brks$source <- "obs"
  obs_brks[1:n_obs] <- lapply(vars, function(x) {
    formatC(obs_brks[, x], width = 2, flag = "0")
  })
  obs_brks$interval <- apply(obs_brks[vars], 1, paste0, collapse = "-")
  
  obs_pct <- lapply("interval", function(x) {
    temp           <- round(prop.table(table(obs_brks[x])) * 100, 4)
    temp           <- as.data.frame.table(temp)
    temp$Var1      <- as.character(temp$Var1)
    names(temp)[1] <- "interval"
    temp$var <- x
    temp$source <- "obs"
    return(temp)
  })
  obs_pct <- do.call("rbind", obs_pct)
  
  
  # compute weights
  df <- merge(ref_pct, obs_pct, by = c("interval"), all.x = TRUE)
  
  cw <- function(ref, obs) {
    pct <- 1 - round(obs / ref, 4) + 1
    return(pct)
  }
  
  df$wts <- cw(df$Freq.x, df$Freq.y)
  # df$wts2 <- scale(df$wts + min(df$wts, na.rm = TRUE) * -1, center = FALSE)
  df$wts <- ifelse(df$wts < 0.01, 0.01, df$wts)
  
  
  # merge results and tidy
  obs_brks <- merge(obs_brks, df[c("interval", "wts")], by = "interval")
  obs_df   <- merge(obs_df, obs_brks[c("id", "wts")], by  = "id", all.x = TRUE)
  obs_df   <- obs_df[order(obs_df$id), ]
  ref_df$id <- NULL
  
  return(wts = ref_df$wts)
}


  
# plot
test5 <- rbind(var_pct, var_pct_pnt)

test5 %>%
  mutate(interval = factor(interval, levels = as.character(sort(unique(interval))))) %>%
  # filter(var == "DEMNED6") %>%
  # select(Freq, source, interval) %>%
  ggplot(aes(x = Freq, y = interval, col = source)) + 
  geom_point(size = 2, alpha = 0.8) +
  ylab("quantile or category") +
  facet_wrap(~ var, scales = "free") +
  scale_color_manual(values = c("#0000FF", "#F39C12")) +
  ggtitle("Bias in the Pedon Training Data")





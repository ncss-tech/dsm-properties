
library(sf)
library(raster)
library(ggplot2)
library(dplyr)

setwd("G:/100m_covariates")

test <- readRDS("CONUS_nasis_SSURGO_SG100_covarsc.rds")

test <- st_as_sf(test,
                 coords = c("x", "y"),
                 crs = 4326
                 )

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
pat <- paste(vars, collapse = "|")
test <- stack(vars) #, function(x) raster(x))


# sample
npixels <- 1563535900
rs    <- rast(vars[c(1:8, 10:32)])
samp  <- st_sample(read_sf(dsn = "D:/geodata/soils/SSURGO_CONUS_FY19.gdb", layer = "SAPOLYGON"), size = floor(npixels * 0.001), type = "regular")
samp2 <- vect(st_coordinates(samp), crs = "+init=epsg:5070") 
rs_s  <- extract(rs, samp2)
# saveRDS(rs_s, file = "rs_sample.RDS")
rs_s <- readRDS(file = "rs_sample.RDS")


# transform
ppt_idx   <- names(rs_s) %in% vars_l$PPT
temp_idx  <- names(rs_s) %in% vars_l$TEMP
evi_idx   <- names(rs_s) %in% vars_l$EVI
rs_s$PPT  <- apply(rs_s[ppt_idx],  1, sum, na.rm = TRUE)
rs_s$TEMP <- apply(rs_s[temp_idx], 1, mean, na.rm = TRUE)
rs_s$EVI  <- apply(rs_s[evi_idx],  1, mean, na.rm = TRUE)
# rs_s$PM <- as.factor(rs_s$PMTGSS7)
# rs_s$NLCD <- as.factor(rs_s$NLCD116)


# subset
vars <- c("SLPNED6", "POSNED6", "EVI", "PPT", "TEMP")
rs_sub <- rs_s[vars]


# tabulate raster
# idx <- sapply(rs_sub, is.numeric)

brks <- lapply(vars, function(x) {
  if (x == "POSNED6") {
    p = seq(0, 1, 0.5)
    } else p = seq(0, 1, 0.1)
  brks <- quantile(rs_sub[x], probs = p, na.rm = TRUE)
  })
names(brks) <- vars

rs_sub[1:ncol(rs_sub)] <- lapply(vars, function(x) {
  if (x == "POSNED6") {
    p = seq(0, 1, 0.5)
  } else p = seq(0, 1, 0.1)
  brks <- quantile(rs_sub[x], probs = p, na.rm = TRUE)
  cut(rs_sub[, x], breaks = unique(brks))
  })
rs_sub$source <- "CONUS"

var_pct <- lapply(vars, function(x) {
  temp = round(prop.table(table(rs_sub[x])) * 100, 1)
  temp = as.data.frame.table(temp)
  temp$Var1 <- as.integer(temp$Var1)
  names(temp)[1] = "interval"
  temp$var = x
  temp$source = "CONUS"
  return(temp)
})
names(var_pct) <- vars[-6]
var_pct <- do.call("rbind", var_pct)


# tabulate pedons
pts  <- as.data.frame(test)
ppt_idx  <- names(pts) %in% vars_l$PPT
temp_idx <- names(pts) %in% vars_l$TEMP
evi_idx  <- names(pts) %in% vars_l$EVI
pts$PPT  <- apply(pts[ppt_idx],  1,  sum, na.rm = TRUE)
pts$TEMP <- apply(pts[temp_idx], 1, mean, na.rm = TRUE)
pts$EVI  <- apply(pts[evi_idx],  1, mean, na.rm = TRUE)
# pts$PM   <- as.factor(pts$PMTGSS7)
pts <- pts[names(pts) %in% vars]

pts_brks <- lapply(vars, function(x) {
  temp = pts[x]
  if (is.numeric(temp[[1]])) {
    temp_brks = brks[[x]]
    temp[, 1] = cut(temp[, 1], breaks = unique(temp_brks))
  } else temp
  return(temp)
})
pts_brks <- do.call("cbind", pts_brks)
pts_brks$source <- "points"

var_pct_pnt <- lapply(vars, function(x) {
  temp = round(prop.table(table(pts_brks[x])) * 100, 1)
  temp = as.data.frame.table(temp)
  temp$Var1 <- as.integer(temp$Var1)
  names(temp)[1] = "interval"
  temp$var = x
  temp$source = "pedons"
  return(temp)
})
names(var_pct_pnt) <- vars
var_pct_pnt <- do.call("rbind", var_pct_pnt)


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


# compute weights
df <- merge(var_pct, var_pct_pnt, by = c("var", "interval"), all.x = TRUE)

bw <- function(ref, obs) {
  pct <- 1 - round(obs / ref, 2) + 1
  return(pct)
}

wts <- bw(df$Freq.x, df$Freq.y)
summary(wts)


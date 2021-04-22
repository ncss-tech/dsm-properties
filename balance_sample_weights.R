
library(sf)
library(raster)
library(ggplot2)


test <- readRDS("CONUS_nasis_SSURGO_SG100_covarsc.rds")

test <- st_as_sf(test,
                 coords = c("x", "y"),
                 crs = 4326
                 )

lf <- list.files("G:/100m_covariates", pattern = ".tif$", full.names = TRUE)

vars_l <- list(
  DEM = "DEMNED6",
  SLOPE = "SLPNED6",
  NLCD  = "NLCD116",
  PM    = "PMTGSS7",
  PPT   = paste0("P",  formatC(1:12, width = 2, flag = "0"), "PRI5"),
  TEMP  = paste0("T",  formatC(1:12, width = 2, flag = "0"), "PRI5") 
)
vars <- paste0("G:/100m_covariates/", unlist(vars_l), ".tif")
pat <- paste(vars, collapse = "|")
test <- stack(vars[5], function(x) raster(x))


# sample
rs    <- stack(vars[c(1:5, 6:28)])
samp  <- st_sample(read_sf(dsn = "D:/geodata/soils/SSURGO_CONUS_FY19.gdb", layer = "SAPOLYGON"), size = 100000, type = "regular")
rs_s  <- as.data.frame(extract(rs, as(samp, "Spatial")))


# transform
ppt_idx  <- names(rs_s) %in% vars_l$PPT
temp_idx <- names(rs_s) %in% vars_l$TEMP
rs_s$PPT <- apply(rs_s[ppt_idx], 1, sum, na.rm = TRUE)
rs_s$TEMP <- apply(rs_s[temp_idx], 1, mean, na.rm = TRUE)
rs_s$PM <- as.factor(rs_s$PMTGSS7)
rs_s$NLCD <- as.factor(rs_s$NLCD116)


# subset
vars <- c("DEMNED6", "SLPNED6", "PPT", "TEMP", "NLCD", "PM")
rs_sub <- rs_s[vars]


# tabulate raster
idx <- sapply(rs_sub, is.numeric)

brks <- lapply(rs_sub[idx], function(x) {
  brks <- quantile(x, probs = seq(0, 1, 0.1), na.rm = TRUE)
  })

rs_sub[idx] <- lapply(rs_sub[idx], function(x) {
  brks <- quantile(x, probs = seq(0, 1, 0.1), na.rm = TRUE)
  cut(x, breaks = unique(brks))
  })
rs_sub$source <- "CONUS"

var_pct <- lapply(vars[-6], function(x) {
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
test2 <- as.data.frame(test)
ppt_idx  <- names(test2) %in% vars_l$PPT
temp_idx <- names(test2) %in% vars_l$TEMP
test2$PPT  <- apply(test2[ppt_idx], 1,  sum, na.rm = TRUE)
test2$TEMP <- apply(test2[temp_idx], 1, mean, na.rm = TRUE)
test2$NLCD <- as.factor(test2$NLCD116)
# test2$PM   <- as.factor(test2$PMTGSS7)
test3 <- test2[names(test2) %in% vars]

test4 <- lapply(vars[1:5], function(x) {
  temp = test3[names(test3) %in% x]
  if (is.numeric(temp[[1]])) {
    temp_brks = brks[names(brks) == x][1][[1]]
    temp[1] = cut(temp[[1]], breaks = unique(temp_brks))
  } else temp
  return(temp)
})
test4 <- do.call("cbind", test4)
test4$source <- "points"

var_pct_pnt <- lapply(vars[-6], function(x) {
  temp = round(prop.table(table(test4[x])) * 100, 1)
  temp = as.data.frame.table(temp)
  temp$Var1 <- as.integer(temp$Var1)
  names(temp)[1] = "interval"
  temp$var = x
  temp$source = "pedons"
  return(temp)
})
names(var_pct_pnt) <- vars[-6]
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
  facet_wrap(~ var, scales = "free_y") +
  scale_color_manual(values = c("#0000FF", "#F39C12")) +
  ggtitle("Bias in the Pedon Training Data")


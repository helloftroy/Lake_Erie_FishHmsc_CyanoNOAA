# Fit sdmTMB for 4 western Lake Erie WB-trawl species:
#   yellow perch, walleye, white perch, emerald shiner
#
# Design (per user spec):
#   - station effect  -> persistent spatial random field (spatial = "on")
#   - year effect     -> random intercept (1 | year)
#   - exposure        -> bloom_days_current + bloom_days_lag1 (separate terms)
#   - covariate       -> surface_temp
#   - effort offset   -> log(area_m2), passed via sdmTMB's `offset` arg
#
# Only rows with complete fields AND adequate CI coverage (current + lag1)
# are used -- 637 of 911 events, 2014-2024, all 82 stations (see
# processed/sdmtmb_input.csv / scripts/18_build_sdmtmb_dataset.py).

library(sdmTMB)
library(dplyr)
library(sf)

setwd("/Users/hellpark/multimodal_seusmbol/great_lakes_edna_feasibility")

df <- read.csv("processed/sdmtmb_input.csv")
df <- df %>%
  filter(!is.na(surface_temp), !is.na(bloom_days_current), !is.na(bloom_days_lag1),
         adequate_current == "True", adequate_lag1 == "True")
cat(sprintf("Fitting on %d station-years, %d unique stations, years %d-%d\n",
            nrow(df), length(unique(df$serial)), min(df$year), max(df$year)))

# UTM 17N (meters) for the mesh -- matches the OLCI CI raster CRS used earlier
pts <- st_as_sf(df, coords = c("lon", "lat"), crs = 4326)
pts_utm <- st_transform(pts, crs = 32617)
coords <- st_coordinates(pts_utm)
df$X <- coords[, 1] / 1000  # km, sdmTMB convention
df$Y <- coords[, 2] / 1000

df$year_f <- as.factor(df$year)
df$log_area <- log(df$area_m2)
# standardize continuous covariates for fitting stability
df$bloom_current_s <- scale(df$bloom_days_current)
df$bloom_lag1_s <- scale(df$bloom_days_lag1)
df$temp_s <- scale(df$surface_temp)

mesh <- make_mesh(df, xy_cols = c("X", "Y"), n_knots = 40, type = "kmeans")
cat(sprintf("Mesh built: %d knots over %d stations\n", mesh$mesh$n, length(unique(df$serial))))

species <- list(
  yellow_perch   = "count_yellow_perch",
  walleye        = "count_walleye",
  white_perch    = "count_white_perch",
  emerald_shiner = "count_emerald_shiner"
)

results <- list()
dir.create("processed/sdmtmb_fits", showWarnings = FALSE)

for (nm in names(species)) {
  col <- species[[nm]]
  cat("\n==================== ", nm, " ====================\n")
  df$y <- df[[col]]
  cat(sprintf("  N>0: %d/%d (%.1f%%), mean count (given >0): %.1f\n",
              sum(df$y > 0), nrow(df), 100 * mean(df$y > 0), mean(df$y[df$y > 0])))

  fit <- tryCatch({
    sdmTMB(
      y ~ 1 + bloom_current_s + bloom_lag1_s + temp_s + (1 | year_f),
      data = df,
      mesh = mesh,
      family = nbinom2(link = "log"),
      spatial = "on",
      offset = df$log_area
    )
  }, error = function(e) { cat("FIT FAILED: ", conditionMessage(e), "\n"); NULL })

  if (!is.null(fit)) {
    print(fit)
    s <- tryCatch(sanity(fit), error = function(e) NULL)
    print(s)
    saveRDS(fit, sprintf("processed/sdmtmb_fits/%s.rds", nm))
    capture.output(print(fit), print(summary(fit)$coefficients), file = sprintf("processed/sdmtmb_fits/%s_summary.txt", nm))
    results[[nm]] <- fit
  }
}

cat("\n\nDone. Fitted objects saved to processed/sdmtmb_fits/*.rds\n")

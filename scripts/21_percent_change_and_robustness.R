# (1) Convert bloom coefficients to % change in catch per +19 bloom-days
#     (one residual SD, from the 2026-09-30 variance decomposition), with 95% CI.
# (2) No-temperature model: does removing surface_temp change the bloom
#     coefficients? (checks whether temp is masking/absorbing a bloom signal)
#     Also: raw correlation between bloom_days and surface_temp in the fit data.
# (3) Refit using the continuous intensity-weighted CI exposure
#     (cumulative_CI, not the composite-count threshold bloom_days) for
#     current + lag1.

library(sdmTMB)
library(dplyr)

setwd("/Users/hellpark/multimodal_seusmbol/great_lakes_edna_feasibility")

df <- read.csv("processed/sdmtmb_input.csv")
df <- df %>%
  filter(!is.na(surface_temp), !is.na(bloom_days_current), !is.na(bloom_days_lag1),
         adequate_current == "True", adequate_lag1 == "True")

# need the continuous cumulative_CI exposure too -- pull from the per-station-year
# CI table (already computed, not in sdmtmb_input.csv)
ci <- read.csv("processed/ci_exposure_all_stations.csv")
ci_cur <- ci %>% select(serial, year, cumulative_CI) %>% rename(cum_CI_current = cumulative_CI)
ci_lag <- ci %>% select(serial, year, cumulative_CI) %>% mutate(year = year + 1) %>%
  rename(cum_CI_lag1 = cumulative_CI)
df <- df %>% left_join(ci_cur, by = c("serial", "year")) %>% left_join(ci_lag, by = c("serial", "year"))

library(sf)
pts <- st_as_sf(df, coords = c("lon", "lat"), crs = 4326)
pts_utm <- st_transform(pts, crs = 32617)
coords <- st_coordinates(pts_utm)
df$X <- coords[, 1] / 1000
df$Y <- coords[, 2] / 1000
df$year_f <- as.factor(df$year)
df$log_area <- log(df$area_m2)
df$bloom_current_s <- as.numeric(scale(df$bloom_days_current))
df$bloom_lag1_s <- as.numeric(scale(df$bloom_days_lag1))
df$temp_s <- as.numeric(scale(df$surface_temp))
df$cumCI_current_s <- as.numeric(scale(df$cum_CI_current))
df$cumCI_lag1_s <- as.numeric(scale(df$cum_CI_lag1))

mesh <- make_mesh(df, xy_cols = c("X", "Y"), n_knots = 40, type = "kmeans")

# ---------------------------------------------------- (2a) bloom vs temp correlation
cat("\n==================== (2) Bloom-days vs temperature correlation ====================\n")
cat(sprintf("cor(bloom_days_current, surface_temp) = %.3f\n",
            cor(df$bloom_days_current, df$surface_temp, use = "complete.obs")))
cat(sprintf("cor(bloom_days_lag1, surface_temp)    = %.3f\n",
            cor(df$bloom_days_lag1, df$surface_temp, use = "complete.obs")))
cat(sprintf("cor(cum_CI_current, surface_temp)     = %.3f\n",
            cor(df$cum_CI_current, df$surface_temp, use = "complete.obs")))

species <- list(
  yellow_perch   = "count_yellow_perch",
  walleye        = "count_walleye",
  white_perch    = "count_white_perch",
  emerald_shiner = "count_emerald_shiner"
)

pct_rows <- list()
notemp_rows <- list()
intensity_rows <- list()

for (nm in names(species)) {
  col <- species[[nm]]
  df$y <- df[[col]]
  cat("\n==================== ", nm, " ====================\n")

  # -------------------------------------------------- baseline (already fit) reload
  fit_base <- readRDS(sprintf("processed/sdmtmb_fits/%s.rds", nm))
  tt <- tidy(fit_base, conf.int = TRUE)

  # (1) percent change per +19 raw bloom-days
  sd_current <- sd(df$bloom_days_current)
  sd_lag1 <- sd(df$bloom_days_lag1)
  for (term_name in c("bloom_current_s", "bloom_lag1_s")) {
    row <- tt %>% filter(term == term_name)
    sd_raw <- if (term_name == "bloom_current_s") sd_current else sd_lag1
    mult <- 19 / sd_raw  # convert "per 1 SD of standardized var" -> "per 19 raw days"
    pct_est <- (exp(row$estimate * mult) - 1) * 100
    pct_lo  <- (exp(row$conf.low  * mult) - 1) * 100
    pct_hi  <- (exp(row$conf.high * mult) - 1) * 100
    pct_rows[[length(pct_rows) + 1]] <- data.frame(
      species = nm, term = term_name, pct_change_per_19days = pct_est,
      ci_low = pct_lo, ci_high = pct_hi)
  }

  # -------------------------------------------------- (2) no-temperature refit
  fit_notemp <- tryCatch({
    sdmTMB(y ~ 1 + bloom_current_s + bloom_lag1_s + (1 | year_f),
           data = df, mesh = mesh, family = nbinom2(link = "log"),
           spatial = "on", offset = df$log_area)
  }, error = function(e) { cat("no-temp FIT FAILED: ", conditionMessage(e), "\n"); NULL })
  if (!is.null(fit_notemp)) {
    tt2 <- tidy(fit_notemp, conf.int = TRUE) %>% filter(term %in% c("bloom_current_s", "bloom_lag1_s"))
    tt2$species <- nm
    tt2$model <- "no_temperature"
    notemp_rows[[nm]] <- tt2
  }

  # -------------------------------------------------- (3) intensity-weighted continuous exposure
  fit_intensity <- tryCatch({
    sdmTMB(y ~ 1 + cumCI_current_s + cumCI_lag1_s + temp_s + (1 | year_f),
           data = df, mesh = mesh, family = nbinom2(link = "log"),
           spatial = "on", offset = df$log_area)
  }, error = function(e) { cat("intensity FIT FAILED: ", conditionMessage(e), "\n"); NULL })
  if (!is.null(fit_intensity)) {
    tt3 <- tidy(fit_intensity, conf.int = TRUE) %>%
      filter(term %in% c("cumCI_current_s", "cumCI_lag1_s", "temp_s"))
    tt3$species <- nm
    intensity_rows[[nm]] <- tt3
    saveRDS(fit_intensity, sprintf("processed/sdmtmb_fits/%s_intensity.rds", nm))
  }
}

pct_df <- bind_rows(pct_rows)
write.csv(pct_df, "processed/sdmtmb_pct_change_per_19days.csv", row.names = FALSE)
cat("\n\n==================== (1) Percent change in catch per +19 bloom-days ====================\n")
print(pct_df)

notemp_df <- bind_rows(notemp_rows)
write.csv(notemp_df, "processed/sdmtmb_notemp_coefficients.csv", row.names = FALSE)
cat("\n==================== (2) No-temperature model bloom coefficients ====================\n")
print(notemp_df)
cat("\nCompare to baseline (with temperature) bloom coefficients in processed/sdmtmb_coefficients.csv\n")

intensity_df <- bind_rows(intensity_rows)
write.csv(intensity_df, "processed/sdmtmb_intensity_coefficients.csv", row.names = FALSE)
cat("\n==================== (3) Intensity-weighted continuous CI exposure coefficients ====================\n")
print(intensity_df)

# -------------------------------------------------- (4) YOY / recruitment refit
cat("\n\n==================== (4) YOY (age-0 / recruitment) models ====================\n")
df_yoy <- read.csv("processed/sdmtmb_input_yoy.csv")
df_yoy <- df_yoy %>%
  filter(!is.na(surface_temp), !is.na(bloom_days_current), !is.na(bloom_days_lag1),
         adequate_current == "True", adequate_lag1 == "True")
pts_yoy <- st_as_sf(df_yoy, coords = c("lon", "lat"), crs = 4326)
pts_yoy_utm <- st_transform(pts_yoy, crs = 32617)
coords_yoy <- st_coordinates(pts_yoy_utm)
df_yoy$X <- coords_yoy[, 1] / 1000
df_yoy$Y <- coords_yoy[, 2] / 1000
df_yoy$year_f <- as.factor(df_yoy$year)
df_yoy$log_area <- log(df_yoy$area_m2)
df_yoy$bloom_current_s <- as.numeric(scale(df_yoy$bloom_days_current))
df_yoy$bloom_lag1_s <- as.numeric(scale(df_yoy$bloom_days_lag1))
df_yoy$temp_s <- as.numeric(scale(df_yoy$surface_temp))
mesh_yoy <- make_mesh(df_yoy, xy_cols = c("X", "Y"), n_knots = 40, type = "kmeans")

yoy_species <- list(
  yellow_perch   = "yoy_yellow_perch",
  walleye        = "yoy_walleye",
  white_perch    = "yoy_white_perch",
  emerald_shiner = "yoy_emerald_shiner"
)
yoy_rows <- list()
for (nm in names(yoy_species)) {
  col <- yoy_species[[nm]]
  df_yoy$y <- df_yoy[[col]]
  cat(sprintf("\n-- YOY %s: N>0 = %d/%d (%.1f%%)\n", nm, sum(df_yoy$y > 0), nrow(df_yoy),
              100 * mean(df_yoy$y > 0)))
  fit_yoy <- tryCatch({
    sdmTMB(y ~ 1 + bloom_current_s + bloom_lag1_s + temp_s + (1 | year_f),
           data = df_yoy, mesh = mesh_yoy, family = nbinom2(link = "log"),
           spatial = "on", offset = df_yoy$log_area)
  }, error = function(e) { cat("YOY FIT FAILED: ", conditionMessage(e), "\n"); NULL })
  if (!is.null(fit_yoy)) {
    s <- tryCatch(sanity(fit_yoy), error = function(e) NULL)
    cat(sprintf("  sanity all_ok: %s\n", if (!is.null(s)) s$all_ok else NA))
    tt4 <- tidy(fit_yoy, conf.int = TRUE)
    tt4$species <- nm
    yoy_rows[[nm]] <- tt4
    saveRDS(fit_yoy, sprintf("processed/sdmtmb_fits/%s_yoy.rds", nm))
  }
}
yoy_df <- bind_rows(yoy_rows)
write.csv(yoy_df, "processed/sdmtmb_yoy_coefficients.csv", row.names = FALSE)
cat("\nYOY coefficients:\n")
print(yoy_df %>% filter(term %in% c("bloom_current_s", "bloom_lag1_s", "temp_s")))

cat("\n\nDone.\n")

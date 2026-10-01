# (5) Smooth (non-linear) bloom-days term: does a threshold/saturation
# effect exist that the linear specification would miss?
# y ~ s(bloom_days_current) + s(bloom_days_lag1) + temp_s + (1 | year_f)

library(sdmTMB)
library(dplyr)
library(sf)
library(ggplot2)

setwd("/Users/hellpark/multimodal_seusmbol/great_lakes_edna_feasibility")

df <- read.csv("processed/sdmtmb_input.csv")
df <- df %>%
  filter(!is.na(surface_temp), !is.na(bloom_days_current), !is.na(bloom_days_lag1),
         adequate_current == "True", adequate_lag1 == "True")

pts <- st_as_sf(df, coords = c("lon", "lat"), crs = 4326)
pts_utm <- st_transform(pts, crs = 32617)
coords <- st_coordinates(pts_utm)
df$X <- coords[, 1] / 1000
df$Y <- coords[, 2] / 1000
df$year_f <- as.factor(df$year)
df$log_area <- log(df$area_m2)
df$temp_s <- as.numeric(scale(df$surface_temp))

mesh <- make_mesh(df, xy_cols = c("X", "Y"), n_knots = 40, type = "kmeans")

species <- list(
  yellow_perch   = "count_yellow_perch",
  walleye        = "count_walleye",
  white_perch    = "count_white_perch",
  emerald_shiner = "count_emerald_shiner"
)

edf_rows <- list()
pred_list <- list()

for (nm in names(species)) {
  col <- species[[nm]]
  df$y <- df[[col]]
  cat("\n====================", nm, "====================\n")

  fit_smooth <- tryCatch({
    sdmTMB(y ~ 1 + s(bloom_days_current, k = 4) + s(bloom_days_lag1, k = 4) + temp_s + (1 | year_f),
           data = df, mesh = mesh, family = nbinom2(link = "log"),
           spatial = "on", offset = df$log_area)
  }, error = function(e) { cat("SMOOTH FIT FAILED: ", conditionMessage(e), "\n"); NULL })

  if (is.null(fit_smooth)) next
  s <- tryCatch(sanity(fit_smooth), error = function(e) NULL)
  cat(sprintf("sanity all_ok: %s\n", if (!is.null(s)) s$all_ok else NA))
  print(fit_smooth)
  saveRDS(fit_smooth, sprintf("processed/sdmtmb_fits/%s_smooth.rds", nm))

  # effective degrees of freedom for each smooth (close to 1 = ~linear; higher = curved)
  sm <- fit_smooth$sd_report
  tryCatch({
    p <- plot_smooth(fit_smooth, select = 1, ggplot = TRUE) + ggtitle(paste(nm, "- bloom_days_current"))
    ggsave(sprintf("figures/smooth_%s_current.png", nm), p, width = 6, height = 4, dpi = 150)
    p2 <- plot_smooth(fit_smooth, select = 2, ggplot = TRUE) + ggtitle(paste(nm, "- bloom_days_lag1"))
    ggsave(sprintf("figures/smooth_%s_lag1.png", nm), p2, width = 6, height = 4, dpi = 150)
  }, error = function(e) cat("plot_smooth failed: ", conditionMessage(e), "\n"))
}

cat("\n\nDone.\n")

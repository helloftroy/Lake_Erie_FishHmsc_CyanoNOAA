# Finalized Hmsc base model (item 0) + two trait analyses per user's
# strategic reprioritization (2026-10-01):
#   Model A (PRIMARY): 17-species community, TrFormula = broad traits
#     (feeding guild, habitat position, thermal guild) -- well-powered
#     formal community trait test.
#   Model B (FOCUSED/EXPLORATORY, historical hypothesis test): 6
#     Ludsin-classified species only (4 tolerant + Smallmouth Bass + Rock
#     Bass intolerant), TrFormula = eutrophication tolerance.
#
# Base spec (both models): presence/absence (probit); cumulative CI
# current + lag1 (standardized, continuous -- NOT bloom-day counts);
# surface temperature (standardized); year as FIXED categorical effect;
# effort (log area_m2, standardized) included since it genuinely varies
# (CV=14.4%); station as a SPATIAL random level using real UTM coordinates
# (not a plain factor random level like the first Hmsc pass). No
# phylogeny, no extra spatial field, no other covariates.

library(Hmsc)
library(sf)
set.seed(1)
setwd("/Users/hellpark/multimodal_seusmbol/great_lakes_edna_feasibility")

community <- read.csv("processed/hmsc_community_v2.csv")
traits <- read.csv("processed/hmsc_traits_v2.csv")
rownames(traits) <- make.names(traits$species)

main_species <- c("Walleye","Yellow.Perch","Freshwater.Drum","White.Perch","White.Bass","Trout.perch",
                   "Channel.Catfish","Gizzard.Shad","White.Sucker","Rainbow.Smelt","Emerald.Shiner",
                   "Round.Goby","Spottail.Shiner","Silver.Chub","Quillback","Common.Carp","Alewife")
ludsin_species <- c("Channel.Catfish","Common.Carp","Quillback","White.Sucker","Smallmouth.Bass","Rock.Bass")

# ---- shared spatial coordinates (UTM 17N, km -- same projection used throughout this project)
pts <- st_as_sf(community, coords = c("lon", "lat"), crs = 4326)
pts_utm <- st_transform(pts, crs = 32617)
coords <- st_coordinates(pts_utm) / 1000
community$X <- coords[, 1]
community$Y <- coords[, 2]

build_and_fit <- function(species_cols, tr_formula, label, samples = 1000, transient = 500, thin = 2) {
  cat("\n\n============================================================\n")
  cat("Model:", label, "\n")
  cat("Species:", paste(species_cols, collapse = ", "), "\n")

  Y <- as.matrix(community[, species_cols])
  Ypa <- (Y > 0) * 1
  cat(sprintf("Community matrix: %d sites x %d species\n", nrow(Ypa), ncol(Ypa)))
  print(round(colMeans(Ypa), 2))

  XData <- data.frame(
    cumCI_current_s = as.numeric(scale(community$cum_CI_current)),
    cumCI_lag1_s = as.numeric(scale(community$cum_CI_lag1)),
    temp_s = as.numeric(scale(community$surface_temp)),
    log_area_s = as.numeric(scale(log(community$area_m2))),
    year_f = as.factor(community$year)
  )
  XFormula <- ~ cumCI_current_s + cumCI_lag1_s + temp_s + log_area_s + year_f

  TrData <- traits[species_cols, ]
  TrData$feeding_guild <- as.factor(TrData$feeding_guild)
  TrData$habitat_position <- as.factor(TrData$habitat_position)
  TrData$thermal_guild <- as.factor(TrData$thermal_guild)
  if ("eutrophication_tolerance" %in% names(TrData)) {
    TrData$eutrophication_tolerance <- as.factor(TrData$eutrophication_tolerance)
  }

  # station as a SPATIAL random level (real coordinates, not a plain factor)
  station_coords <- community[!duplicated(community$serial), c("serial", "X", "Y")]
  rownames(station_coords) <- as.character(station_coords$serial)
  station_coords_m <- as.matrix(station_coords[, c("X", "Y")])
  # Several station-serial pairs (e.g. 121/521) share EXACTLY identical GPS
  # coordinates (confirmed: 9 pairs, same physical site, likely paired
  # sub-series within the survey). Hmsc's spatial random level requires
  # unique locations. Fix: deterministic micro-jitter (<=2m, far below any
  # ecologically meaningful spatial scale, fixed seed for reproducibility)
  # applied only to exact-duplicate coordinates.
  set.seed(42)
  dup_mask <- duplicated(station_coords_m) | duplicated(station_coords_m, fromLast = TRUE)
  if (any(dup_mask)) {
    cat(sprintf("Jittering %d stations sharing exact-duplicate coordinates (<=2m)\n", sum(dup_mask)))
    jitter_km <- 0.002  # 2 meters
    station_coords_m[dup_mask, ] <- station_coords_m[dup_mask, ] +
      matrix(runif(sum(dup_mask) * 2, -jitter_km, jitter_km), ncol = 2)
  }
  studyDesign <- data.frame(station = as.factor(community$serial))
  rL_station <- HmscRandomLevel(sData = station_coords_m)

  m <- Hmsc(Y = Ypa, XData = XData, XFormula = XFormula,
            TrData = TrData, TrFormula = tr_formula,
            studyDesign = studyDesign, ranLevels = list(station = rL_station),
            distr = "probit")

  cat(sprintf("\nFitting MCMC (2 chains, %d samples, %d transient, thin %d)...\n", samples, transient, thin))
  t0 <- Sys.time()
  m <- sampleMcmc(m, thin = thin, samples = samples, transient = transient, nChains = 2,
                   verbose = 500, nParallel = 1)
  cat(sprintf("Fit time: %.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))

  saveRDS(m, sprintf("processed/hmsc_fit_%s.rds", label))

  mpost <- convertToCodaObject(m)
  psrf_beta <- gelman.diag(mpost$Beta, multivariate = FALSE)$psrf
  psrf_gamma <- gelman.diag(mpost$Gamma, multivariate = FALSE)$psrf
  cat("Beta PSRF summary:\n"); print(summary(psrf_beta[, 1]))
  cat("Gamma PSRF summary:\n"); print(summary(psrf_gamma[, 1]))

  list(model = m, label = label)
}

# ---- Model A: PRIMARY, 17-species, broad traits
resA <- build_and_fit(main_species, ~ feeding_guild + habitat_position + thermal_guild, "A_primary_17species")

# ---- Model B: FOCUSED/EXPLORATORY, 6 Ludsin species, tolerance trait
resB <- build_and_fit(ludsin_species, ~ eutrophication_tolerance, "B_ludsin_focused_6species",
                       samples = 1500, transient = 750, thin = 2)

cat("\n\nAll done.\n")

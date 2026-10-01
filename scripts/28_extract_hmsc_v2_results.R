library(Hmsc)
library(dplyr)
library(ggplot2)
setwd("/Users/hellpark/multimodal_seusmbol/great_lakes_edna_feasibility")

# ============================================================ Model A: primary 17-species
mA <- readRDS("processed/hmsc_fit_A_primary_17species.rds")

postA_beta <- getPostEstimate(mA, parName = "Beta")
beta_mean <- postA_beta$mean
beta_support <- postA_beta$support
x_names <- colnames(mA$X)
rownames(beta_mean) <- x_names
rownames(beta_support) <- x_names
colnames(beta_mean) <- mA$spNames
colnames(beta_support) <- mA$spNames

betaA_df <- data.frame(
  species = mA$spNames,
  cumCI_current_mean = beta_mean["cumCI_current_s", ],
  cumCI_current_support = beta_support["cumCI_current_s", ],
  cumCI_lag1_mean = beta_mean["cumCI_lag1_s", ],
  cumCI_lag1_support = beta_support["cumCI_lag1_s", ],
  temp_mean = beta_mean["temp_s", ],
  temp_support = beta_support["temp_s", ]
)
traits <- read.csv("processed/hmsc_traits_v2.csv")
rownames(traits) <- make.names(traits$species)
betaA_df <- cbind(betaA_df, traits[betaA_df$species, c("feeding_guild","habitat_position","thermal_guild")])
write.csv(betaA_df, "processed/hmsc_v2_speciesA_beta.csv", row.names = FALSE)
cat("==================== Model A: species-level bloom coefficients (17 species) ====================\n")
print(betaA_df[order(-betaA_df$cumCI_current_mean), ], digits = 3)

# Gamma: broad trait interactions
postA_gamma <- getPostEstimate(mA, parName = "Gamma")
gamma_mean <- postA_gamma$mean
gamma_support <- postA_gamma$support
tr_names <- colnames(mA$Tr)
rownames(gamma_mean) <- x_names; colnames(gamma_mean) <- tr_names
rownames(gamma_support) <- x_names; colnames(gamma_support) <- tr_names
cat("\n==================== Model A: Gamma (broad trait x environment) for bloom terms ====================\n")
gamma_bloom <- rbind(
  data.frame(env = "cumCI_current_s", trait = tr_names, mean = gamma_mean["cumCI_current_s", ], support = gamma_support["cumCI_current_s", ]),
  data.frame(env = "cumCI_lag1_s", trait = tr_names, mean = gamma_mean["cumCI_lag1_s", ], support = gamma_support["cumCI_lag1_s", ])
)
print(gamma_bloom, digits = 3)
write.csv(gamma_bloom, "processed/hmsc_v2_gammaA_broadtraits.csv", row.names = FALSE)

# R2T: trait-explained variance in species environmental responses
cat("\n==================== Model A: variance partitioning + R2T ====================\n")
VP <- tryCatch(computeVariancePartitioning(mA), error = function(e) { cat("VP failed:", conditionMessage(e), "\n"); NULL })
if (!is.null(VP)) {
  cat("Variance partitioning by predictor group (fraction of explained variance per species):\n")
  print(round(VP$vals, 3))
  if (!is.null(VP$R2T)) {
    cat("\nR2T$Beta (trait-explained variance in species environmental responses):\n")
    print(VP$R2T$Beta)
  }
}

# predictive power (Tjur R2 for probit models, simple in-sample check)
preds <- computePredictedValues(mA, expected = TRUE)
evalA <- evaluateModelFit(hM = mA, predY = preds)
cat("\nModel A in-sample fit (Tjur R2 per species, presence/absence):\n")
print(round(evalA$TjurR2, 3))
write.csv(data.frame(species = mA$spNames, TjurR2 = evalA$TjurR2), "processed/hmsc_v2_modelA_fit.csv", row.names = FALSE)

# ============================================================ Model B: focused Ludsin 6-species
mB <- readRDS("processed/hmsc_fit_B_ludsin_focused_6species.rds")

postB_beta <- getPostEstimate(mB, parName = "Beta")
beta_meanB <- postB_beta$mean
beta_supportB <- postB_beta$support
xB_names <- colnames(mB$X)
rownames(beta_meanB) <- xB_names; rownames(beta_supportB) <- xB_names
colnames(beta_meanB) <- mB$spNames; colnames(beta_supportB) <- mB$spNames

betaB_df <- data.frame(
  species = mB$spNames,
  cumCI_current_mean = beta_meanB["cumCI_current_s", ],
  cumCI_current_support = beta_supportB["cumCI_current_s", ],
  cumCI_lag1_mean = beta_meanB["cumCI_lag1_s", ],
  cumCI_lag1_support = beta_supportB["cumCI_lag1_s", ]
)
betaB_df$tolerance <- traits[betaB_df$species, "eutrophication_tolerance"]
write.csv(betaB_df, "processed/hmsc_v2_speciesB_beta.csv", row.names = FALSE)
cat("\n\n==================== Model B: Ludsin-focused species bloom coefficients (6 species) ====================\n")
print(betaB_df, digits = 3)

# Gamma: tolerance x bloom interaction (THE key parameter)
postB_gamma <- getPostEstimate(mB, parName = "Gamma")
gamma_meanB <- postB_gamma$mean
gamma_supportB <- postB_gamma$support
trB_names <- colnames(mB$Tr)
rownames(gamma_meanB) <- xB_names; colnames(gamma_meanB) <- trB_names
rownames(gamma_supportB) <- xB_names; colnames(gamma_supportB) <- trB_names

cat("\n==================== Model B: tolerance x bloom Gamma (THE key test) ====================\n")
mpostB <- convertToCodaObject(mB)
gamma_samples <- as.matrix(mpostB$Gamma)
# find column indices for tolerance_tolerant x cumCI terms
cat("Gamma parameter names:\n"); print(colnames(gamma_samples))

gammaB_df <- data.frame(env = rep(xB_names, each = length(trB_names)),
                          trait = rep(trB_names, times = length(xB_names)),
                          mean = as.vector(t(gamma_meanB)),
                          support = as.vector(t(gamma_supportB)))
write.csv(gammaB_df, "processed/hmsc_v2_gammaB_tolerance.csv", row.names = FALSE)
print(gammaB_df[gammaB_df$env %in% c("cumCI_current_s","cumCI_lag1_s"), ], digits = 3)

preds_B <- computePredictedValues(mB, expected = TRUE)
evalB <- evaluateModelFit(hM = mB, predY = preds_B)
cat("\nModel B in-sample fit (Tjur R2 per species):\n")
print(round(evalB$TjurR2, 3))

cat("\n\nExtraction done.\n")

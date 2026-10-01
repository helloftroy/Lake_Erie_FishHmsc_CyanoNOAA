library(sdmTMB)
library(dplyr)
library(ggplot2)

setwd("/Users/hellpark/multimodal_seusmbol/great_lakes_edna_feasibility")

species <- c("yellow_perch", "walleye", "white_perch", "emerald_shiner")
all_coefs <- list()

for (nm in species) {
  fit <- readRDS(sprintf("processed/sdmtmb_fits/%s.rds", nm))
  tt <- tidy(fit, conf.int = TRUE)
  tt$species <- nm
  all_coefs[[nm]] <- tt
}

coefs <- bind_rows(all_coefs)
write.csv(coefs, "processed/sdmtmb_coefficients.csv", row.names = FALSE)
print(coefs)

# ---- forest plot: bloom_current_s and bloom_lag1_s across species
plot_df <- coefs %>% filter(term %in% c("bloom_current_s", "bloom_lag1_s", "temp_s"))
plot_df$species <- factor(plot_df$species, levels = rev(species))
plot_df$term <- factor(plot_df$term, levels = c("bloom_current_s", "bloom_lag1_s", "temp_s"),
                        labels = c("Bloom days (current season)", "Bloom days (lag-1 year)", "Surface temperature"))

p <- ggplot(plot_df, aes(x = estimate, y = species)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey40") +
  geom_errorbarh(aes(xmin = conf.low, xmax = conf.high), height = 0.2, color = "#0072B2") +
  geom_point(size = 3, color = "#0072B2") +
  facet_wrap(~term, scales = "free_x") +
  labs(x = "Coefficient estimate (standardized covariate, log-count scale)", y = NULL,
       title = "sdmTMB coefficients: bloom-days exposure and temperature, 4 western Lake Erie species",
       subtitle = "Points = MLE, bars = 95% CI. CI crossing the dashed zero line = not significant.") +
  theme_minimal(base_size = 12)

ggsave("figures/sdmtmb_coefficient_forest.png", p, width = 10, height = 5, dpi = 150)
cat("Saved figures/sdmtmb_coefficient_forest.png\n")

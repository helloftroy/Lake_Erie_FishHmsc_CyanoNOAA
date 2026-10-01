library(dplyr)
library(ggplot2)
setwd("/Users/hellpark/multimodal_seusmbol/great_lakes_edna_feasibility")

# ---- Model A: all 17 species, colored by feeding guild
dfA <- read.csv("processed/hmsc_v2_speciesA_beta.csv")
longA <- bind_rows(
  dfA %>% transmute(species, term = "Current season", mean = cumCI_current_mean, support = cumCI_current_support, feeding_guild),
  dfA %>% transmute(species, term = "Lag-1 year", mean = cumCI_lag1_mean, support = cumCI_lag1_support, feeding_guild)
)
longA$species <- gsub("\\.", " ", longA$species)
longA$credible <- longA$support >= 0.95 | longA$support <= 0.05
order_sp <- dfA %>% arrange(cumCI_current_mean) %>% pull(species) %>% gsub("\\.", " ", .)
longA$species <- factor(longA$species, levels = order_sp)

p1 <- ggplot(longA, aes(x = mean, y = species, color = feeding_guild)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey40") +
  geom_point(aes(size = credible)) +
  scale_size_manual(values = c(`TRUE` = 4, `FALSE` = 2), guide = "none") +
  scale_color_manual(values = c(benthivore = "#D55E00", invertivore = "#0072B2",
                                 piscivore = "#009E73", planktivore = "#CC79A7")) +
  facet_wrap(~term) +
  labs(x = "Posterior mean (cumulative CI, standardized; presence/absence probit scale)", y = NULL,
       color = "Feeding guild",
       title = "Model A (primary): 17-species real-spatial Hmsc, species-level bloom effects",
       subtitle = "Large points = posterior support >=95%. Real spatial field (station), year as fixed effect, continuous CI exposure.") +
  theme_minimal(base_size = 11)
ggsave("figures/hmsc_v2_modelA_species.png", p1, width = 11, height = 7, dpi = 150)

# ---- Model B: Ludsin-focused 6 species
dfB <- read.csv("processed/hmsc_v2_speciesB_beta.csv")
longB <- bind_rows(
  dfB %>% transmute(species, term = "Current season", mean = cumCI_current_mean, support = cumCI_current_support, tolerance),
  dfB %>% transmute(species, term = "Lag-1 year", mean = cumCI_lag1_mean, support = cumCI_lag1_support, tolerance)
)
longB$species <- gsub("\\.", " ", longB$species)
longB$credible <- longB$support >= 0.95 | longB$support <= 0.05

p2 <- ggplot(longB, aes(x = mean, y = species, color = tolerance)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey40") +
  geom_point(aes(size = credible)) +
  scale_size_manual(values = c(`TRUE` = 5, `FALSE` = 3), guide = "none") +
  scale_color_manual(values = c(tolerant = "#0072B2", intolerant = "#D55E00")) +
  facet_wrap(~term) +
  labs(x = "Posterior mean (cumulative CI, standardized; presence/absence probit scale)", y = NULL,
       color = "Ludsin et al. 2001\ntolerance",
       title = "Model B (focused/exploratory): Ludsin-classified species only (n=6)",
       subtitle = "Historical hypothesis test, NOT a decisive community-wide result. Large points = posterior support >=95%.") +
  theme_minimal(base_size = 11)
ggsave("figures/hmsc_v2_modelB_ludsin.png", p2, width = 9, height = 5, dpi = 150)

cat("saved both plots\n")

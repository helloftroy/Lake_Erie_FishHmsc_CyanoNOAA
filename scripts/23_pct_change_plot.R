library(dplyr)
library(ggplot2)
setwd("/Users/hellpark/multimodal_seusmbol/great_lakes_edna_feasibility")

df <- read.csv("processed/sdmtmb_pct_change_per_19days.csv")
df$term <- factor(df$term, levels = c("bloom_current_s", "bloom_lag1_s"),
                   labels = c("Current season", "Lag-1 year"))
species_order <- c("emerald_shiner", "white_perch", "walleye", "yellow_perch")
df$species <- factor(df$species, levels = species_order)

p <- ggplot(df, aes(x = pct_change_per_19days, y = species)) +
  annotate("rect", xmin = -30, xmax = 30, ymin = -Inf, ymax = Inf, fill = "grey90", alpha = 0.5) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey40") +
  geom_errorbarh(aes(xmin = ci_low, xmax = ci_high), height = 0.2, color = "#D55E00", linewidth = 0.8) +
  geom_point(size = 3, color = "#D55E00") +
  facet_wrap(~term) +
  labs(x = "% change in catch per +19 bloom-days (one residual SD)", y = NULL,
       title = "Bloom-days exposure effect size, in interpretable units",
       subtitle = "Grey band = ±30% (\"no large effect\" zone). Bars extending past it = data can't rule out a large effect.") +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank())

ggsave("figures/sdmtmb_pct_change_forest.png", p, width = 10, height = 5, dpi = 150)
cat("saved\n")

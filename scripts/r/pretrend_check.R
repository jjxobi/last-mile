# Pilot gate. Before touching the staggered-adoption estimator, check
# whether the treated-to-be countries and the never-treated comparison
# pool look like they were on parallel paths before anyone got Starlink.
# If they weren't, per the project's own preregistered rule, that's the
# result -- not something to fix by picking different controls after
# looking at this.

library(dplyr)
library(ggplot2)

# run from the repo root, e.g.:
#   "C:/Program Files/R/R-4.6.1/bin/Rscript.exe" scripts/r/pretrend_check.R
panel <- read.csv(file.path("data", "processed", "panel.csv"))

earliest_treat <- min(panel$gvar[panel$gvar > 0])
pre <- panel %>% filter(period < earliest_treat)

pre$is_treated_group <- pre$gvar > 0

# slope of median download speed vs period, treated-to-be vs never-treated,
# fit separately over the pre-period only
slopes <- pre %>%
  group_by(is_treated_group) %>%
  summarise(
    slope = coef(lm(median_d_mbps ~ period))[["period"]],
    intercept = coef(lm(median_d_mbps ~ period))[["(Intercept)"]],
    .groups = "drop"
  )
print(slopes)

# formal test: does a treated_group x period interaction matter in the
# pre-period alone
interaction_model <- lm(median_d_mbps ~ period * is_treated_group, data = pre)
interaction_summary <- summary(interaction_model)
cat("\npre-trend interaction test (period x is_treated_group):\n")
print(interaction_summary$coefficients)

pretrend_p <- interaction_summary$coefficients["period:is_treated_groupTRUE", "Pr(>|t|)"]
cat(sprintf("\npre-trend interaction p-value: %.4f\n", pretrend_p))

dir.create(file.path("site", "assets"), showWarnings = FALSE, recursive = TRUE)

p <- ggplot(panel, aes(x = period, y = median_d_mbps, color = country, group = country)) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 1.6) +
  geom_vline(xintercept = earliest_treat - 0.5, linetype = "dashed", color = "gray40") +
  annotate("text", x = earliest_treat - 0.5, y = max(panel$median_d_mbps) * 0.95,
           label = "first treatment quarter", hjust = -0.05, size = 3, color = "gray30") +
  labs(
    title = "Median fixed download speed by country, quarterly",
    subtitle = "Dashed line marks the first quarter any pilot country had Starlink available",
    x = "Panel period (1 = 2022 Q1, 12 = 2024 Q4)",
    y = "Median download speed (Mbps)",
    color = NULL
  ) +
  theme_minimal(base_size = 12)

ggsave(file.path("site", "assets", "pretrend.png"), p, width = 8, height = 5, dpi = 150)

result <- list(
  earliest_treat_period = earliest_treat,
  pretrend_interaction_p = pretrend_p,
  passes_pilot_gate = pretrend_p > 0.10
)

writeLines(
  sprintf(
    "earliest_treat_period: %d\npretrend_interaction_p: %.4f\npasses_pilot_gate: %s\n",
    result$earliest_treat_period, result$pretrend_interaction_p, result$passes_pilot_gate
  ),
  file.path("data", "processed", "pretrend_result.txt")
)

cat("\n", if (result$passes_pilot_gate) "PILOT GATE: PASS (p > 0.10, no strong evidence of a pre-existing differential trend)\n"
    else "PILOT GATE: FAIL (p <= 0.10, treated-to-be and control countries were not on a parallel path before treatment)\n")

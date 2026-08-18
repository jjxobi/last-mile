# Same Rambachan & Roth (2021) sensitivity check as sensitivity_honestdid.R,
# run against the India-only-control robustness estimate instead of the
# primary six-country one. The writeup flagged this as a real gap rather
# than a skipped step when the robustness check first went up -- this
# closes it.
#
# Run after robustness_narrow_control.R (needs data/processed/dynamic_agg_narrow.rds).

library(did)
library(HonestDiD)

source(file.path("scripts", "r", "honest_did_helper.R"))

dynamic_agg_narrow <- readRDS(file.path("data", "processed", "dynamic_agg_narrow.rds"))

sensitivity <- honest_did(
  dynamic_agg_narrow,
  e = 0,
  type = "relative_magnitude",
  Mbarvec = seq(0.5, 2, by = 0.5)
)

print(sensitivity$orig_ci)
print(sensitivity$robust_ci)

dir.create(file.path("site", "assets"), showWarnings = FALSE, recursive = TRUE)

sens_plot <- createSensitivityPlot_relativeMagnitudes(sensitivity$robust_ci, sensitivity$orig_ci) +
  ggplot2::labs(
    title = "Sensitivity check on the robustness estimate (India-only control)",
    subtitle = "Rambachan & Roth (2021) relative-magnitude bounds, Mbar = how many times the worst pre-trend deviation"
  )

ggplot2::ggsave(file.path("site", "assets", "robustness_sensitivity.png"), sens_plot, width = 8, height = 5, dpi = 150)

write.csv(sensitivity$robust_ci, file.path("data", "processed", "robustness_honestdid_robust_ci.csv"), row.names = FALSE)
cat("wrote data/processed/robustness_honestdid_robust_ci.csv and site/assets/robustness_sensitivity.png\n")

breaks_at_1 <- sensitivity$robust_ci[abs(sensitivity$robust_ci$Mbar - 1) < 1e-9, ]
cat("\nAt Mbar = 1 (post-treatment trend violation allowed to be as large as the worst pre-treatment one):\n")
print(breaks_at_1)

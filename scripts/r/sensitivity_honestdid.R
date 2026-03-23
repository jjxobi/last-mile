# Rambachan & Roth (2021) sensitivity analysis on the parallel-trends
# assumption behind estimate_att.R's event study. The pretrend_check.R gate
# asks "do pre-trends look parallel." This asks the sharper follow-up: how
# much would parallel trends have to be violated, post-treatment, before
# the "on impact" effect stops being distinguishable from zero. That's a
# more honest way to lean on a design than just reporting a p-value on the
# pre-trend test and moving on.

library(did)
library(HonestDiD)

source(file.path("scripts", "r", "honest_did_helper.R"))

dynamic_agg <- readRDS(file.path("data", "processed", "dynamic_agg.rds"))

# relative-magnitude bounds: how many times larger than the worst observed
# pre-trend deviation would the post-treatment trend violation have to be
# before the effect is no longer significant. Standard Mbar grid from the
# Rambachan-Roth paper's own examples.
sensitivity <- honest_did(
  dynamic_agg,
  e = 0,
  type = "relative_magnitude",
  Mbarvec = seq(0.5, 2, by = 0.5)
)

print(sensitivity$orig_ci)
print(sensitivity$robust_ci)

dir.create(file.path("site", "assets"), showWarnings = FALSE, recursive = TRUE)

sens_plot <- createSensitivityPlot_relativeMagnitudes(sensitivity$robust_ci, sensitivity$orig_ci) +
  ggplot2::labs(
    title = "How fragile is the on-impact effect to a violated parallel-trends assumption",
    subtitle = "Rambachan & Roth (2021) relative-magnitude bounds, Mbar = how many times the worst pre-trend deviation"
  )

ggplot2::ggsave(file.path("site", "assets", "sensitivity.png"), sens_plot, width = 8, height = 5, dpi = 150)

write.csv(sensitivity$robust_ci, file.path("data", "processed", "honestdid_robust_ci.csv"), row.names = FALSE)
cat("wrote data/processed/honestdid_robust_ci.csv and site/assets/sensitivity.png\n")

breaks_at_1 <- sensitivity$robust_ci[abs(sensitivity$robust_ci$Mbar - 1) < 1e-9, ]
cat("\nAt Mbar = 1 (post-treatment trend violation allowed to be as large as the worst pre-treatment one):\n")
print(breaks_at_1)

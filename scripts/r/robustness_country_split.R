# The India-only-control robustness check reports one number for the
# "Nigeria/Philippines cohort" (+4.2 Mbps), because att_gt's group-time ATT
# is a within-cohort average across every unit sharing a treatment quarter.
# That blends two countries into one number, and a look at their raw
# trajectories (data/processed/panel.csv) suggests they don't look alike:
# Nigeria's gap from its own pre-treatment base grows steadily and
# monotonically quarter over quarter, while the Philippines had already
# surged well before Starlink arrived (roughly doubled from period 1 to
# period 4, before any treatment) and its post-treatment gap from base
# fades back down rather than growing.
#
# That's a real question about whether the cohort-level effect is
# detectable only in aggregate (both countries move together, blended
# result) or is really coming from one country and not the other. Answering
# it needs each country run as its own single-treated-unit estimate against
# the same control pool, not read off raw levels by hand.
#
# Same India-only control pool as robustness_narrow_control.R (Kenya still
# serves as a not-yet-treated control for periods before it flips at 7).

library(did)
library(dplyr)
library(ggplot2)

panel <- read.csv(file.path("data", "processed", "panel.csv"))
excluded <- c("THA", "VNM")
narrow <- panel %>% filter(!iso3 %in% excluded)

run_single_country <- function(target_iso3) {
  data <- narrow %>% filter(iso3 %in% c(target_iso3, "KEN", "IND"))
  att_gt_result <- att_gt(
    yname = "median_d_mbps",
    tname = "period",
    idname = "id",
    gname = "gvar",
    data = data,
    control_group = "notyettreated",
    bstrap = TRUE,
    biters = 2000,
    cband = TRUE,
    clustervars = "id",
    base_period = "universal"
  )
  simple_agg <- aggte(att_gt_result, type = "simple")
  dynamic_agg <- aggte(att_gt_result, type = "dynamic")
  list(att_gt = att_gt_result, simple = simple_agg, dynamic = dynamic_agg)
}

cat("=== Nigeria alone vs Kenya (pre-period 7) + India ===\n")
nga <- run_single_country("NGA")
print(summary(nga$simple))
print(summary(nga$dynamic))

cat("\n\n=== Philippines alone vs Kenya (pre-period 7) + India ===\n")
phl <- run_single_country("PHL")
print(summary(phl$simple))
print(summary(phl$dynamic))

dir.create(file.path("site", "assets"), showWarnings = FALSE, recursive = TRUE)

make_plot <- function(dynamic_agg, title) {
  ggdid(dynamic_agg) +
    labs(
      title = title,
      subtitle = "Single-country estimate vs India-only control. Diagnostic on top of a diagnostic.",
      x = "Quarters relative to Starlink becoming available",
      y = "Effect on median download speed (Mbps)"
    ) +
    theme_minimal(base_size = 12)
}

ggsave(
  file.path("site", "assets", "robustness_nigeria_only.png"),
  make_plot(nga$dynamic, "Nigeria alone, India-only control"),
  width = 8, height = 5, dpi = 150
)
ggsave(
  file.path("site", "assets", "robustness_philippines_only.png"),
  make_plot(phl$dynamic, "Philippines alone, India-only control"),
  width = 8, height = 5, dpi = 150
)

comparison <- data.frame(
  spec = c("nigeria_only", "philippines_only"),
  overall_att = c(nga$simple$overall.att, phl$simple$overall.att),
  overall_se = c(nga$simple$overall.se, phl$simple$overall.se)
)
write.csv(comparison, file.path("data", "processed", "robustness_country_split_summary.csv"), row.names = FALSE)
cat("\n\nwrote data/processed/robustness_country_split_summary.csv\n")
print(comparison)

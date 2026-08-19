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
# First version of this script got the isolation wrong: it filtered each
# dataset down to one target country plus Kenya plus India, then called
# aggte(type = "simple") or aggte(type = "dynamic"), both of which
# aggregate across every treated cohort still present in the data -- and
# Kenya still carries its own gvar = 7, so it is its own treated cohort in
# that filtered dataset, not just a control. Those aggregations silently
# blended the target country's effect with Kenya's, which is exactly the
# kind of thing this project exists to catch, not commit.
#
# Root-caused in scripts/r/diagnose_pooling_discrepancy.R: a from-scratch
# hand calculation using the same control set matches did::att_gt's raw
# group-time table for group 5 exactly, at every period, under both "reg"
# and "dr" estimation methods -- so the control-pool composition was never
# the issue, and this isn't a property of the doubly-robust estimator
# either. The fix is to read the raw att_gt group-time table directly,
# filtered to the target country's own group, instead of routing through
# an aggte() aggregation that mixes cohorts.
#
# The event-time point estimates below are exact matches to a plain
# by-hand 2x2 difference-in-differences computed straight from
# data/processed/panel.csv -- verified in diagnose_pooling_discrepancy.R,
# not asserted here.

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

  # raw group-time table, filtered to this country's own cohort (group 5)
  # only -- bypasses aggte() entirely so Kenya's group 7 never gets mixed
  # in, whatever aggregation type would otherwise have blended it.
  own_group <- data.frame(
    t = att_gt_result$t,
    g = att_gt_result$group,
    att = att_gt_result$att,
    se = att_gt_result$se
  ) %>%
    filter(g == 5) %>%
    arrange(t) %>%
    mutate(event = t - 5)

  # type = "group" also correctly isolates group 5 from group 7 (it
  # reports each cohort's effect as its own row rather than blending), so
  # this is used as an independent cross-check on the overall number, not
  # a different quantity.
  group_agg <- aggte(att_gt_result, type = "group")
  idx <- which(group_agg$egt == 5)

  list(own_group = own_group, overall_att = group_agg$att.egt[idx], overall_se = group_agg$se.egt[idx])
}

cat("=== Nigeria alone vs Kenya (pre-period 7) + India, group-isolated ===\n")
nga <- run_single_country("NGA")
print(nga$own_group)
cat(sprintf("\nNigeria's own isolated cohort effect (group aggregation): %.4f (se %.4f)\n", nga$overall_att, nga$overall_se))

cat("\n\n=== Philippines alone vs Kenya (pre-period 7) + India, group-isolated ===\n")
phl <- run_single_country("PHL")
print(phl$own_group)
cat(sprintf("\nPhilippines' own isolated cohort effect (group aggregation): %.4f (se %.4f)\n", phl$overall_att, phl$overall_se))

dir.create(file.path("site", "assets"), showWarnings = FALSE, recursive = TRUE)

make_plot <- function(own_group, title) {
  own_group$period_type <- ifelse(own_group$event < 0, "Pre", "Post")
  ggplot(own_group, aes(x = event, y = att, color = period_type)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    geom_pointrange(aes(ymin = att - 1.96 * se, ymax = att + 1.96 * se)) +
    labs(
      title = title,
      subtitle = "Raw group-time table for this country's own cohort only, Kenya excluded from the aggregate",
      x = "Quarters relative to Starlink becoming available",
      y = "Effect on median download speed (Mbps)",
      color = NULL
    ) +
    theme_minimal(base_size = 12)
}

ggsave(
  file.path("site", "assets", "robustness_nigeria_only.png"),
  make_plot(nga$own_group, "Nigeria alone, India-only control"),
  width = 8, height = 5, dpi = 150
)
ggsave(
  file.path("site", "assets", "robustness_philippines_only.png"),
  make_plot(phl$own_group, "Philippines alone, India-only control"),
  width = 8, height = 5, dpi = 150
)

comparison <- data.frame(
  spec = c("nigeria_only_isolated", "philippines_only_isolated"),
  overall_att = c(nga$overall_att, phl$overall_att),
  overall_se = c(nga$overall_se, phl$overall_se)
)
write.csv(comparison, file.path("data", "processed", "robustness_country_split_summary.csv"), row.names = FALSE)
cat("\n\nwrote data/processed/robustness_country_split_summary.csv\n")
print(comparison)

cat(sprintf(
  "\nmean of the two isolated country point estimates: %.4f (compare to the pooled cohort's +4.17)\n",
  mean(c(nga$overall_att, phl$overall_att))
))

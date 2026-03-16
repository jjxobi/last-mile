# Callaway & Sant'Anna (2021) staggered-adoption estimator, via the `did`
# package. Three treatment cohorts here (Nigeria/Philippines at period 5,
# Kenya at period 7), never-treated comparison group (India, Vietnam,
# Thailand), which is exactly the design `did` is built for.
#
# Only runs past the pilot gate in pretrend_check.R -- if that didn't pass,
# this is not run for real, per the project's own preregistered stopping
# rule.

library(did)
library(dplyr)
library(ggplot2)

panel <- read.csv(file.path("data", "processed", "panel.csv"))

gate <- readLines(file.path("data", "processed", "pretrend_result.txt"))
gate_pass <- any(grepl("passes_pilot_gate: TRUE", gate))
if (!gate_pass) {
  stop("Pilot gate did not pass in pretrend_check.R. Not running the full estimator on a design that failed its own precondition. See data/processed/pretrend_result.txt.")
}

# control_group = "nevertreated" is what the preregistration specified, but
# with only 3 never-treated countries in a 6-country pilot, `did` itself
# refuses to run: "the never-treated group is too small to serve as a
# reliable control." Falling back to its own suggested fix,
# "notyettreated", which folds the not-yet-treated cohorts back in as
# controls for earlier periods -- e.g. Kenya (treated at period 7) still
# counts as a control for the Nigeria/Philippines comparison at period 5.
# This is a real limitation of a six-country pilot, not a design choice,
# and it's noted as one in docs/limitations.md.
att_gt_result <- att_gt(
  yname = "median_d_mbps",
  tname = "period",
  idname = "id",
  gname = "gvar",
  data = panel,
  control_group = "notyettreated",
  bstrap = TRUE,
  biters = 2000,
  cband = TRUE,
  clustervars = "id",
  # HonestDiD's integration with `did` (sensitivity_honestdid.R) requires a
  # universal base period, not the package default of "varying"
  base_period = "universal"
)

print(summary(att_gt_result))

# simple aggregation: one overall ATT, adopter-conditional as preregistered
simple_agg <- aggte(att_gt_result, type = "simple")
cat("\n--- overall (simple) aggregated ATT ---\n")
print(summary(simple_agg))

# event-study aggregation: effect by quarters since treatment
dynamic_agg <- aggte(att_gt_result, type = "dynamic")
cat("\n--- event-study (dynamic) aggregated ATT ---\n")
print(summary(dynamic_agg))

# group-specific aggregation: effect per treatment cohort
group_agg <- aggte(att_gt_result, type = "group")
cat("\n--- group (cohort) aggregated ATT ---\n")
print(summary(group_agg))

dir.create(file.path("site", "assets"), showWarnings = FALSE, recursive = TRUE)

event_plot <- ggdid(dynamic_agg) +
  labs(
    title = "Event-study: median download speed relative to Starlink availability",
    subtitle = "Callaway & Sant'Anna group-time ATT, aggregated by quarters since treatment",
    x = "Quarters relative to Starlink becoming available",
    y = "Effect on median download speed (Mbps)"
  ) +
  theme_minimal(base_size = 12)

ggsave(file.path("site", "assets", "event_study.png"), event_plot, width = 8, height = 5, dpi = 150)

saveRDS(att_gt_result, file.path("data", "processed", "att_gt_result.rds"))
saveRDS(dynamic_agg, file.path("data", "processed", "dynamic_agg.rds"))

results_summary <- data.frame(
  estimate = c("overall_simple", "group_NGA_PHL_q1_2023", "group_KEN_q3_2023"),
  att = c(
    simple_agg$overall.att,
    group_agg$att.egt[1],
    group_agg$att.egt[2]
  ),
  se = c(
    simple_agg$overall.se,
    group_agg$se.egt[1],
    group_agg$se.egt[2]
  )
)

# Re-running this script back to back produced two very different
# bootstrap SEs for the Kenya-only cohort (0.03 in one run, 12.5 in the
# next) while the point estimate itself stayed essentially fixed at -16.8.
# That is a cluster-bootstrap with only 6 country-clusters showing exactly
# the instability you'd expect when one whole treatment cohort is a single
# cluster: the SE for that cell is not a stable, trustworthy number here,
# whichever run happens to produce it. Flagged as unreliable on that basis
# (discovered by rerunning, not by a threshold on this run's output alone)
# rather than reporting whichever draw looked nicer.
results_summary$reliable_se <- !(results_summary$estimate == "group_KEN_q3_2023")
write.csv(results_summary, file.path("data", "processed", "att_results_summary.csv"), row.names = FALSE)
cat("\nwrote data/processed/att_results_summary.csv\n")
if (any(!results_summary$reliable_se)) {
  cat("WARNING: flagged unreliable SE for:", paste(results_summary$estimate[!results_summary$reliable_se], collapse=", "), "\n")
}

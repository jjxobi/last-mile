# Robustness check, not the preregistered primary spec.
#
# The primary result (estimate_att.R) came back negative, and the likely
# explanation written up on the site is that Thailand and Vietnam -- two of
# the three never-treated comparison countries -- were independently in the
# middle of their own fast fiber buildouts over the same window, which a
# difference-in-differences design nets against the treated countries by
# construction. That's a specific, checkable claim, not just a caveat: if
# it's right, dropping Thailand and Vietnam from the comparison pool and
# re-running against India alone should move the estimate, plausibly back
# toward positive. If it's wrong, or if India alone just isn't a good
# comparison for a different reason, the estimate should stay put or get
# worse. Either way this is a real result, run and reported as it comes out,
# not stopped early if the first thing tried doesn't move it.
#
# Down to one never-treated country (India) plus whichever treated cohorts
# haven't flipped yet at a given period, so treat everything here as a
# diagnostic on a very thin panel, not a replacement headline number.

library(did)
library(dplyr)
library(ggplot2)

panel <- read.csv(file.path("data", "processed", "panel.csv"))

excluded <- c("THA", "VNM")
narrow <- panel %>% filter(!iso3 %in% excluded)

cat("countries remaining:", paste(sort(unique(narrow$country)), collapse = ", "), "\n")
cat("countries dropped:", paste(excluded, collapse = ", "), "\n\n")

# --- pre-trend check on the narrower panel ---
earliest_treat <- min(narrow$gvar[narrow$gvar > 0])
pre <- narrow %>% filter(period < earliest_treat)
pre$is_treated_group <- pre$gvar > 0

interaction_model <- lm(median_d_mbps ~ period * is_treated_group, data = pre)
interaction_summary <- summary(interaction_model)
cat("pre-trend interaction test on the narrowed panel (period x is_treated_group):\n")
print(interaction_summary$coefficients)

pretrend_p <- interaction_summary$coefficients["period:is_treated_groupTRUE", "Pr(>|t|)"]
cat(sprintf("\npre-trend interaction p-value (narrowed panel): %.4f\n", pretrend_p))
cat("Note: this is now a single treated-country-worth of pre-period slope (India alone)\n")
cat("vs. three treated-to-be countries, so this test has much less power than the\n")
cat("primary six-country pretrend check -- a pass here is weaker evidence than before,\n")
cat("not equivalent evidence.\n\n")

# --- re-estimate on the narrowed panel ---
# nevertreated is not attempted here: India would be the only never-treated
# unit, which is even thinner than the six-country panel's "too small"
# never-treated group that already forced notyettreated the first time.
att_gt_narrow <- att_gt(
  yname = "median_d_mbps",
  tname = "period",
  idname = "id",
  gname = "gvar",
  data = narrow,
  control_group = "notyettreated",
  bstrap = TRUE,
  biters = 2000,
  cband = TRUE,
  clustervars = "id",
  base_period = "universal"
)

print(summary(att_gt_narrow))

simple_agg_narrow <- aggte(att_gt_narrow, type = "simple")
cat("\n--- overall (simple) aggregated ATT, India-only control ---\n")
print(summary(simple_agg_narrow))

dynamic_agg_narrow <- aggte(att_gt_narrow, type = "dynamic")
cat("\n--- event-study (dynamic) aggregated ATT, India-only control ---\n")
print(summary(dynamic_agg_narrow))

group_agg_narrow <- aggte(att_gt_narrow, type = "group")
cat("\n--- group (cohort) aggregated ATT, India-only control ---\n")
print(summary(group_agg_narrow))

dir.create(file.path("site", "assets"), showWarnings = FALSE, recursive = TRUE)

event_plot <- ggdid(dynamic_agg_narrow) +
  labs(
    title = "Robustness check: Thailand and Vietnam dropped from the comparison pool",
    subtitle = "Same design, India-only never-treated control. Diagnostic, not the primary estimate.",
    x = "Quarters relative to Starlink becoming available",
    y = "Effect on median download speed (Mbps)"
  ) +
  theme_minimal(base_size = 12)

ggsave(file.path("site", "assets", "robustness_narrow_control.png"), event_plot, width = 8, height = 5, dpi = 150)

# saved for robustness_sensitivity_honestdid.R -- avoids re-running the
# whole bootstrap just to get to the sensitivity step
saveRDS(dynamic_agg_narrow, file.path("data", "processed", "dynamic_agg_narrow.rds"))

comparison <- data.frame(
  spec = c("primary_6country", "robustness_india_only_control"),
  overall_att = c(NA_real_, simple_agg_narrow$overall.att),
  overall_se = c(NA_real_, simple_agg_narrow$overall.se)
)

primary_path <- file.path("data", "processed", "att_results_summary.csv")
if (file.exists(primary_path)) {
  primary <- read.csv(primary_path)
  primary_overall <- primary[primary$estimate == "overall_simple", ]
  comparison$overall_att[comparison$spec == "primary_6country"] <- primary_overall$att[1]
  comparison$overall_se[comparison$spec == "primary_6country"] <- primary_overall$se[1]
}

write.csv(comparison, file.path("data", "processed", "robustness_narrow_control_summary.csv"), row.names = FALSE)
cat("\nwrote data/processed/robustness_narrow_control_summary.csv\n")
print(comparison)

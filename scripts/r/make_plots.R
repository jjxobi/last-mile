# Pulls together the headline numbers from estimate_att.R into a single
# summary chart for the site. pretrend_check.R, estimate_att.R, and
# sensitivity_honestdid.R each already save their own diagnostic plot at
# the point they're computed; this one is just the "so what" chart.

library(ggplot2)
library(dplyr)

results <- read.csv(file.path("data", "processed", "att_results_summary.csv"))

# Kenya's cohort-only estimate carries a numerically degenerate SE (see the
# comment in estimate_att.R) -- charting it with a 95% CI built on that SE
# would show a nonsensically narrow band that looks more precise than the
# data supports. Left out of the chart; still in the CSV.
n_dropped <- sum(!results$reliable_se)
if (n_dropped > 0) {
  cat(sprintf("dropping %d estimate(s) with unreliable SE from the chart: %s\n",
              n_dropped, paste(results$estimate[!results$reliable_se], collapse = ", ")))
}
results <- results %>% filter(reliable_se)

results <- results %>%
  mutate(
    label = case_when(
      estimate == "overall_simple" ~ "Overall (adopter-conditional)",
      estimate == "group_NGA_PHL_q1_2023" ~ "Nigeria & Philippines cohort",
      estimate == "group_KEN_q3_2023" ~ "Kenya cohort",
      TRUE ~ estimate
    ),
    ci_low = att - 1.96 * se,
    ci_high = att + 1.96 * se
  )

p <- ggplot(results, aes(x = label, y = att)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  geom_pointrange(aes(ymin = ci_low, ymax = ci_high), size = 0.9, linewidth = 1) +
  coord_flip() +
  labs(
    title = "Estimated effect of Starlink availability on median download speed",
    subtitle = "Callaway-Sant'Anna ATT, adopter-conditional, 95% CI",
    x = NULL,
    y = "Change in median download speed (Mbps)"
  ) +
  theme_minimal(base_size = 12)

dir.create(file.path("site", "assets"), showWarnings = FALSE, recursive = TRUE)
ggsave(file.path("site", "assets", "headline_result.png"), p, width = 8, height = 4, dpi = 150)
cat("wrote site/assets/headline_result.png\n")

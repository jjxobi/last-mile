# Not part of the pipeline. One-off diagnostic to answer a specific
# question before anything gets published: does the pooled Nigeria+
# Philippines estimate and the two single-country estimates use the same
# control-pool composition, and if so, why don't they reconstruct each
# other.
#
# att_gt's "notyettreated" control group is defined the same way regardless
# of what else is in the dataset: any unit with gvar > t or gvar == 0.
# With no covariates specified, that should mean the control side of each
# (g,t) cell is the same simple average of India (+ Kenya, before Kenya's
# own period 7) whether Nigeria and Philippines are estimated together or
# apart. First step: check that directly, by hand, against the raw panel,
# with no `did` package involved at all -- this is arithmetic, not a
# statistical claim, so if this doesn't reconcile something is wrong with
# the check itself, not the estimator.

library(dplyr)
library(did)

panel <- read.csv(file.path("data", "processed", "panel.csv"))
narrow <- panel %>% filter(!iso3 %in% c("THA", "VNM"))

base_period <- 4

wide <- narrow %>%
  select(iso3, period, median_d_mbps) %>%
  tidyr::pivot_wider(names_from = period, values_from = median_d_mbps, names_prefix = "p")

get_val <- function(iso, p) wide[[paste0("p", p)]][wide$iso3 == iso]
chg <- function(iso, t) get_val(iso, t) - get_val(iso, base_period)

cat("=== Step 1: hand-computed 2x2 DiD, same India/Kenya control set for all three specs ===\n\n")
rows <- list()
for (t in 5:12) {
  kenya_still_control <- t < 7  # Kenya's own gvar is 7
  if (kenya_still_control) {
    control_chg <- mean(c(chg("KEN", t), chg("IND", t)))
    control_desc <- "KEN+IND"
  } else {
    control_chg <- chg("IND", t)
    control_desc <- "IND only"
  }
  nga_att <- chg("NGA", t) - control_chg
  phl_att <- chg("PHL", t) - control_chg
  pooled_att_by_construction <- mean(c(nga_att, phl_att))
  rows[[length(rows) + 1]] <- data.frame(
    t = t, event = t - 5, control = control_desc,
    nga_alone = round(nga_att, 4), phl_alone = round(phl_att, 4),
    pooled_hand = round(pooled_att_by_construction, 4)
  )
}
handcalc <- bind_rows(rows)
print(handcalc)
cat("\npooled_hand is mean(nga_alone, phl_alone) by construction -- that's arithmetic, not something\n")
cat("that needs the did package to confirm. The question is whether did::att_gt's actual output\n")
cat("for the pooled run matches pooled_hand, and whether its single-country runs match nga_alone/phl_alone.\n\n")

run_att <- function(data, method) {
  att_gt(
    yname = "median_d_mbps", tname = "period", idname = "id", gname = "gvar",
    data = data, control_group = "notyettreated", bstrap = FALSE, cband = FALSE,
    clustervars = "id", base_period = "universal", est_method = method
  )
}

extract_g5 <- function(att_gt_result) {
  df <- data.frame(t = att_gt_result$t, g = att_gt_result$group, att = att_gt_result$att)
  df %>% filter(g == 5) %>% arrange(t) %>% mutate(att = round(att, 4))
}

for (method in c("reg", "dr")) {
  cat(sprintf("=== Step 2: est_method = \"%s\" ===\n", method))

  pooled_data <- narrow
  nga_data <- narrow %>% filter(iso3 %in% c("NGA", "KEN", "IND"))
  phl_data <- narrow %>% filter(iso3 %in% c("PHL", "KEN", "IND"))

  pooled_g5 <- extract_g5(run_att(pooled_data, method))
  nga_g5 <- extract_g5(run_att(nga_data, method))
  phl_g5 <- extract_g5(run_att(phl_data, method))

  compare <- data.frame(
    t = pooled_g5$t,
    pooled_did_output = pooled_g5$att,
    nga_alone_did_output = nga_g5$att,
    phl_alone_did_output = phl_g5$att,
    mean_of_separate = round((nga_g5$att + phl_g5$att) / 2, 4)
  )
  compare$matches_hand <- compare$pooled_did_output == handcalc$pooled_hand
  compare$separate_reconstructs_pooled <- abs(compare$mean_of_separate - compare$pooled_did_output) < 1e-6
  print(compare)
  cat("\n\n")
}

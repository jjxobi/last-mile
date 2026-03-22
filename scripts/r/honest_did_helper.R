# honest_did() / honest_did.AGGTEobj(), verbatim from Ashesh Rambachan's
# HonestDiD package repo (R/honest_did.R, master branch), since the `did`
# package and HonestDiD aren't natively integrated. Not my code -- pulled
# in as-is so estimate_att.R's dynamic aggte() output can be fed straight
# into HonestDiD's sensitivity analysis.
#
# source: https://github.com/asheshrambachan/HonestDiD/blob/master/R/honest_did.R

honest_did <- function(...) UseMethod("honest_did")

honest_did.AGGTEobj <- function(es,
                                e          = 0,
                                type       = c("smoothness", "relative_magnitude"),
                                gridPoints = 100,
                                ...) {

  type <- match.arg(type)

  if (es$type != "dynamic") {
    stop("need to pass in an event study")
  }

  if (es$DIDparams$base_period != "universal") {
    stop("Use a universal base period for honest_did")
  }

  es_inf_func <- es$inf.function$dynamic.inf.func.e

  n <- nrow(es_inf_func)
  V <- t(es_inf_func) %*% es_inf_func / n / n

  referencePeriod <- -1
  consecutivePre  <- !all(diff(es$egt[es$egt <= referencePeriod]) == 1)
  consecutivePost <- !all(diff(es$egt[es$egt >= referencePeriod]) == 1)
  if ( consecutivePre | consecutivePost ) {
    msg <- "honest_did expects a time vector with consecutive time periods;"
    msg <- paste(msg, "please re-code your event study and interpret the results accordingly.", sep="\n")
    stop(msg)
  }

  hasReference <- any(es$egt == referencePeriod)
  if ( hasReference ) {
    referencePeriodIndex <- which(es$egt == referencePeriod)
    V    <- V[-referencePeriodIndex,-referencePeriodIndex]
    beta <- es$att.egt[-referencePeriodIndex]
  } else {
    beta <- es$att.egt
  }

  nperiods <- nrow(V)
  npre     <- sum(1*(es$egt < referencePeriod))
  npost    <- nperiods - npre
  if ( !hasReference & (min(c(npost, npre)) <= 0) ) {
    if ( npost <= 0 ) {
      msg <- "not enough post-periods"
    } else {
      msg <- "not enough pre-periods"
    }
    msg <- paste0(msg, " (check your time vector; note honest_did takes -1 as the reference period)")
    stop(msg)
  }

  baseVec1 <- basisVector(index=(e+1),size=npost)
  orig_ci  <- constructOriginalCS(betahat        = beta,
                                  sigma          = V,
                                  numPrePeriods  = npre,
                                  numPostPeriods = npost,
                                  l_vec          = baseVec1)

  if (type=="relative_magnitude") {
    robust_ci <- createSensitivityResults_relativeMagnitudes(betahat        = beta,
                                                             sigma          = V,
                                                             numPrePeriods  = npre,
                                                             numPostPeriods = npost,
                                                             l_vec          = baseVec1,
                                                             gridPoints     = gridPoints,
                                                             ...)

  } else if (type == "smoothness") {
    robust_ci <- createSensitivityResults(betahat        = beta,
                                          sigma          = V,
                                          numPrePeriods  = npre,
                                          numPostPeriods = npost,
                                          l_vec          = baseVec1,
                                          ...)
  }

  return(list(robust_ci=robust_ci, orig_ci=orig_ci, type=type))
}

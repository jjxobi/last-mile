# Methodology

## What's being measured

For each of six countries, the median fixed-broadband download speed
reported by Ookla's Speedtest Open Data, aggregated from roughly
610m x 610m tiles up to a country-quarter median, for every quarter from
2022 Q1 through 2024 Q4.

Three of those countries (Nigeria, Philippines, Kenya) got commercial
Starlink service partway through that window. Three (India, Vietnam,
Thailand) did not get it at any point in the window, confirmed against
press coverage (`docs/sources.md`), and function as the comparison group.

## Why these six countries

Chosen for having a single, clearly dated, well-corroborated national
Starlink launch (or, for the comparison group, a clearly documented absence
of one through the whole window) -- not because they're the biggest or the
first thought of. A country with a murky, multi-year rollout (found and
discarded during source-checking: Chile, where Starlink ran rural pilot
programs from 2021 before any single clean commercial-launch date) doesn't
give the staggered-adoption estimator a clean treatment date to work with,
so it isn't included in this pilot even though it's an obvious candidate on
paper.

## Why quarterly, country-level, not tile-level or monthly

Ookla's Open Data is published quarterly, which sets the panel's time
resolution. Country-level aggregation, not tile- or city-level, because the
treatment-date reconstruction (`docs/sources.md`) only supports a
national-level date for these six countries -- there's no sub-national
rollout schedule documented well enough to assign a district a treatment
quarter with the same confidence.

## Estimator

Callaway & Sant'Anna (2021) group-time average treatment effect estimator,
via R's `did` package. This is the right tool here specifically because
treatment isn't a single date: Nigeria and the Philippines both flip in
2023 Q1, Kenya flips in 2023 Q3, so there are two distinct "treatment
cohorts," which is exactly the staggered-adoption setting the estimator is
built for rather than a plain two-period diff-in-diff.

Never-treated control group (`control_group = "nevertreated"`), universal
base period (required for the HonestDiD sensitivity step downstream),
clustered by country, 2000 bootstrap iterations for inference.

## Two data-engineering choices worth being explicit about

- **Point-in-polygon country assignment, not a bounding box.** Nigeria and
  Kenya both share long borders with non-target countries. A bounding box
  around each target country would misattribute border-adjacent tiles.
  `scripts/python/fetch_ookla.py` does a real point-in-polygon test against
  Natural Earth admin-0 boundaries.
- **`tile_x`/`tile_y` used directly instead of parsing the `tile` WKT
  polygon column.** Checked against a sample file first: `tile_x`/`tile_y`
  are already the tile centroid longitude/latitude (range matches -180/180
  and -81/81). Parsing WKT for ~6-7 million rows per quarter would have
  been the slow part of the pipeline for no accuracy gain.

## Pilot gate

Before the full estimator runs, `scripts/r/pretrend_check.R` tests whether
the treated-to-be countries and the comparison group show a statistically
distinguishable pre-treatment trend, using only the periods before any
country in the panel was treated. This was decided and written into
`docs/preregistration.md` before the panel existed. If that gate fails,
`scripts/r/estimate_att.R` refuses to run (see the check at the top of that
script) rather than producing a headline number built on a design that
already failed its own precondition.

## Sensitivity check

`scripts/r/sensitivity_honestdid.R` applies Rambachan & Roth's (2021)
relative-magnitude bounds to the "on impact" event-study coefficient: how
large would a post-treatment violation of parallel trends have to be,
relative to the largest pre-treatment deviation actually observed, before
the estimated effect stops being distinguishable from zero. This is a
sharper and more honest complement to the pilot gate's pre-trend p-value,
not a replacement for it.

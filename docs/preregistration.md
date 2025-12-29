# Analysis plan: last-mile speed effect of Starlink availability

Written before the pilot panel is pulled or touched, so the design can't
quietly drift once there's a number on the page.

## Question

In a country where fixed-line broadband was previously dominated by DSL,
fixed wireless, or legacy geostationary satellite, does the quarter Starlink
commercial service becomes available correspond to a change in measured
fixed download speed (Ookla Speedtest Open Data), relative to countries
where it is not yet available?

This is an adopter-conditional question, not a population-average one. Ookla
tiles are only populated where someone actually ran a speed test, so
whatever comes out of this analysis is about the subpopulation that tests
(and, more specifically, the subpopulation that adopts Starlink and tests),
not about the median household in the country. That distinction gets stated
again in `limitations.md` because it is easy to lose track of once there is
a number on the page.

## What counts as a result worth reporting, decided in advance

No specific magnitude is committed to here. The outcome variable is a
country-wide aggregate across every fixed-broadband technology in the
panel, not a Starlink-specific figure, and there wasn't a principled way to
translate published technology-specific speed comparisons into a predicted
shift in that aggregate without knowing Starlink's adoption share in each
country, which isn't available data. Rather than force a number, the
commitment is procedural: an estimate statistically indistinguishable from
zero, or negative, gets reported as exactly that -- not narrowed,
reframed, or quietly walked back once the data is in.

## Pilot gate, before any full build

Per the project's own definition of done: pre-launch trends for the treated
countries must look parallel to the not-yet-treated comparison pool before
any estimation is trusted. If they are not close to parallel, that is
reported as the result and the project stops there rather than proceeding
to a full staggered-adoption build on a shaky foundation.

## Design chosen before seeing the data

- Treated group: Nigeria (commercial availability 2023-01-30), Philippines
  (commercial availability 2023-02-22), Kenya (commercial availability
  2023-07). Three different treatment quarters, which is what makes a
  staggered-adoption estimator (Callaway & Sant'Anna 2021, via R's `did`
  package) the right tool instead of a plain two-period diff-in-diff.
- Comparison pool: India, Vietnam, Thailand. All three had no Starlink
  license or commercial service at any point in the 2022 Q1-2024 Q4 window
  used here, confirmed via press coverage during data collection (see
  `sources.md`), so they function as never-treated controls for the whole
  panel rather than not-yet-treated controls that flip partway through.
- Panel window: 2022 Q1 through 2024 Q4, quarterly, from Ookla's Open Data
  fixed-broadband tiles, aggregated to country-quarter medians.

Dated as written, before the panel exists.

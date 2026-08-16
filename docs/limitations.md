# Limitations

Stated here up front rather than left for someone else to point out.

## Note added after running the pilot

The primary estimate came back negative (about -11.5 Mbps overall, -9.5
Mbps for the Nigeria/Philippines cohort). See `site/index.html` for the
full writeup. The competing-intervention limitation below, written before
the pilot ran, looks like the most plausible explanation for that negative
number once the actual country trajectories are in hand: the never-treated
comparison countries (Thailand, Vietnam especially) were growing fast on
their own over the same window, plausibly from their own fiber buildouts,
which a difference-in-differences design nets against the treated
countries by construction. That is a read of the pattern, not a test that
isolates it -- the synthetic-control check described below still hasn't
been built.

## Second note, after checking that explanation instead of just asserting it

Dropping Thailand and Vietnam from the comparison pool and re-running the
identical design against India alone (`scripts/r/robustness_narrow_control.R`)
moves the overall estimate from -11.5 Mbps to +1.9 Mbps, and the
Nigeria/Philippines cohort specifically to +4.2 Mbps with a standard error
that reproduced identically across six separate reruns, unlike the Kenya
cell in the primary spec which did not. So the competing-intervention
explanation above isn't just a plausible read of the pattern anymore --
checking it moved the number in the direction that explanation implies. It
is still a four-country panel with a single never-treated comparator, and
+4.2 Mbps for one cohort is a modest, adopter-conditional shift, not a
transformative one.

## This measures an adopter-conditional effect, not a population-average one

Ookla tiles only exist where someone ran a speed test. A country flipping
to "Starlink available" doesn't mean the whole country adopted it -- it
means some subset of people who were already dissatisfied enough with DSL,
fixed wireless, or old-generation satellite to pay for a new dish, install
it, and then also happen to run a speed test that lands in Ookla's data.

So whatever number comes out of `scripts/r/estimate_att.R` is the answer to
"among people who show up in speed-test data after Starlink becomes
available in their country, how much faster does the tile-level median
look," not "how much did the typical household's internet speed change
after Starlink became available in their country." Those are different
claims, and the second one is not something this design can support. If a
number from this project gets quoted anywhere, it should carry the first
framing, not the second.

## Self-selection

The households that adopt fastest are disproportionately the most
underserved but still willing and able to pay Starlink's hardware and
monthly cost. That skews the measured jump upward relative to whatever the
true full-population effect would be, if such a thing were even
measurable from this kind of data. Not corrected for here -- reported as
the adopter-conditional number it actually is, per the point above, rather
than adjusted to imply a population claim the design can't back up.

## Competing interventions during the same window

Fixed broadband speeds can move for reasons that have nothing to do with
Starlink: a government fiber subsidy program landing in the same country in
the same years, a currency shock changing what ISPs can afford to import,
a mobile carrier's own network upgrade. None of the three treated countries
here (Nigeria, Philippines, Kenya) were cross-checked against a documented
subsidized-fiber rollout schedule the way the original project brief
specified for a US/Canada RDOF/BEAD angle -- that cross-check is
US/Canada-specific public data and wasn't built for this pilot. Its absence
here is a real gap, not a solved problem, and it's the first thing that
should be added before trusting this design at country scale.

## Six countries, one pilot window

This is a pilot on a hand-picked six-country panel with a single clean
launch date each, not a global estimate. The full pipeline
(`scripts/python/fetch_ookla.py`) can be pointed at more countries and a
longer window -- the code doesn't hardcode the six-country pilot scope
beyond the `TARGET_ISO3` list at the top of the file -- but doing that
means reconstructing sourced treatment dates for each additional country
first (see `docs/sources.md` for what that actually took for six), and
that work has not been done past this pilot set.

## Press-sourced treatment dates, not an official coverage-map record

The original plan was to reconstruct exact coverage-flip dates from Wayback
Machine snapshots of starlink.com's own availability map. That didn't work
-- the map is rendered client-side from an API call, not present in the
static HTML Wayback stores (see `docs/sources.md` for the CDX query that
established this). Dates used instead come from press coverage,
cross-checked against at least two independent outlets per country. Good
enough for quarterly resolution, which is what the panel uses, but not as
precise as a server-logged coverage timestamp would have been.

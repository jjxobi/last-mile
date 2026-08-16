# last-mile

Does a country's internet actually get faster once Starlink shows up, or is
that mostly a story we tell because the anecdotes are good? This checks it
against independent speed-test data instead of taking the marketing at its
word.

Full write-up: `site/index.html` (open it directly in a browser, or serve
the `site/` folder).

Short version: the primary estimate came back negative, and checking the
most likely explanation (a confounded comparison group) moved it to a
small positive cohort-level number. Full explanation, including the most
likely reason why, is in the write-up -- not summarized further here
because it needs the context to not be misread.

## What this is

A staggered-adoption causal design (Callaway & Sant'Anna 2021) run on
Ookla's Speedtest Open Data, comparing countries before and after their
Starlink commercial-launch date against countries that hadn't gotten it yet.
Three treated countries (Nigeria, Philippines, Kenya), three never-treated
comparison countries (India, Vietnam, Thailand), quarterly panel from 2022
through 2024.

Data engineering in Python, causal estimation in R (`did`, `HonestDiD`).
See `docs/methodology.md` for the reasoning behind each design choice, and
`docs/limitations.md` for what this can and can't actually claim.

## Reproducing it

Requires Python 3.11+ (`pandas`, `pyarrow`, `requests`, `shapely`) and R
4.x (`did`, `HonestDiD`, `dplyr`, `ggplot2`).

```
python scripts/python/reconstruct_coverage_dates.py
python scripts/python/fetch_ookla.py       # pulls ~4GB from Ookla's public S3 bucket, takes a while
python scripts/python/build_panel.py

Rscript scripts/r/pretrend_check.R         # pilot gate -- must pass before the next step means anything
Rscript scripts/r/estimate_att.R
Rscript scripts/r/sensitivity_honestdid.R
Rscript scripts/r/make_plots.R
Rscript scripts/r/robustness_narrow_control.R   # diagnostic: same design, Thailand + Vietnam dropped from controls
```

`fetch_ookla.py` downloads one global quarterly file at a time (~350MB
each), filters it down to the six target countries, and deletes the raw
file before moving to the next quarter, so it never needs more than about
one quarter's worth of raw data on disk at once. `data/raw/*.parquet` isn't
checked into the repo for that reason -- rerun the script to regenerate it.

## What's here and what isn't yet

This is a pilot on six hand-picked countries with clean, sourced launch
dates, not a global backfill. The pipeline in `scripts/python/fetch_ookla.py`
isn't hardcoded to just these six past the `TARGET_ISO3` list at the top of
the file, but scaling it up means reconstructing a sourced treatment date
for every additional country first (see `docs/sources.md` for what that
took here), and a real check against competing fiber-subsidy rollouts
(RDOF/BEAD-style programs) for a US/Canada county-level cut, which the
original scope called for and this pilot doesn't include. Both are the
obvious next steps, not secretly-abandoned ones -- see
`docs/limitations.md`.

## Layout

```
data/processed/   clean panel + results, checked in
data/raw/         downloaded Ookla extracts + boundary file, gitignored, regenerate with fetch_ookla.py
scripts/python/   data engineering
scripts/r/        causal estimation
docs/             preregistration, sources, methodology, limitations
site/             the write-up
```

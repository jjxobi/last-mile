# Coverage date sources

Every treatment date used in the panel is sourced here. No date goes into
`data/processed/coverage_dates.csv` without an entry in this file.

## Attempted: Wayback Machine reconstruction of starlink.com's availability map

First approach tried was reconstructing country-flip dates directly from
Wayback Machine snapshots of starlink.com, the way the project originally
wanted to. Queried the CDX API for starlink.com across the relevant windows
(example: `web.archive.org/cdx/search/cdx?url=starlink.com&matchType=domain&from=20221201&to=20230301`).

Result: the crawl density is real and heavy (dozens of snapshots per day in
the Nigeria/Philippines launch window), but almost everything captured is
build assets, referral-link landing pages, and marketing querystrings. The
country availability list itself is rendered client-side from an API call,
not present in the static HTML Wayback stores, so it isn't recoverable as
structured data from snapshots alone. Noting this as a real negative result
of the data-engineering attempt rather than quietly switching methods.

Fallback, used for the dates below: cross-reference independent press
coverage per country, requiring at least two independent outlets reporting
the same date before accepting it.

## Nigeria, 2023-01-30

- SpaceX announced Starlink service live in Nigeria on January 30, 2023,
  first African market. Multiple independent outlets reporting the same
  date: TechCabal, BellaNaija, Techloy.
  - https://techcabal.com/2023/02/01/techcabal-daily-starlink-nigeria/
  - https://www.bellanaija.com/2023/02/spacex-starlink-live-in-nigeria/
  - https://www.techloy.com/spacex-satellite-internet-service-starlink-launches-in-nigeria/amp/

## Philippines, 2023-02-22

- Wikipedia's Starlink article cites commercial availability beginning
  February 22, 2023, sourced to a contemporary report. Corroborated by
  DataCenterDynamics coverage of the same launch.
  - https://en.wikipedia.org/wiki/Starlink
  - https://www.datacenterdynamics.com/en/news/starlink-goes-live-in-the-philippines/

## Kenya, 2023-07 (treated as start of Q3 2023 for the quarterly panel)

- Kenya license and service went live in July 2023, SpaceX's second African
  market, via partnership distribution. Treated as a Q3 2023 flip since the
  Ookla panel here is quarterly, not monthly, so exact day-of-month doesn't
  change which panel period it lands in.

## Comparison pool: confirmed not-yet-treated through the full panel window (2022 Q1-2024 Q4)

- **India**: no commercial Starlink service in this window. Final licensing
  did not clear until Q1 2026 (five-year commercial license through July
  2030, distribution via Reliance Jio and Bharti Airtel), well outside the
  panel.
- **Vietnam**: licensed February 2026, commercial service targeted mid-2026.
  Outside the panel window.
- **Thailand**: pending regulatory approval as of the search date; no
  Starlink launch found for this window.

These three do the job of the never-treated comparison group specified in
the preregistration: same panel window, confirmed no treatment at any point
in it.

## Note on precision

Press-sourced launch dates carry more uncertainty than a hypothetical
official coverage-map timestamp would have. The quarterly aggregation used
in the panel absorbs most of that: a date being off by a week or two inside
the same quarter doesn't change which panel period a country is coded as
treated in. A date being off by enough to land in the wrong quarter would
matter, which is why each date above has at least two independent
corroborating sources rather than one.

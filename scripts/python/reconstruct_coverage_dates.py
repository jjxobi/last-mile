"""
Builds data/processed/coverage_dates.csv from the sourced dates in
docs/sources.md. Every row here has a matching citation there -- this
script does not invent or interpolate any date, it just puts the sourced
ones in a machine-readable form for the panel builder.

Wayback Machine CDX reconstruction of starlink.com's own availability map
was tried first and abandoned: the map is rendered client-side from an API
call, not present in static snapshots. See docs/sources.md for the CDX
query used and what came back. Press-sourced dates, cross-checked against
at least two independent outlets each, were used instead.
"""

import csv
from pathlib import Path

ROWS = [
    # iso3, country, group, treated_quarter (None if never-treated in window)
    ("NGA", "Nigeria",     "treated", "2023-Q1"),
    ("PHL", "Philippines", "treated", "2023-Q1"),
    ("KEN", "Kenya",       "treated", "2023-Q3"),
    ("IND", "India",       "control", None),
    ("VNM", "Vietnam",     "control", None),
    ("THA", "Thailand",    "control", None),
]

OUT_PATH = Path(__file__).resolve().parents[2] / "data" / "processed" / "coverage_dates.csv"


def main():
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with OUT_PATH.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["iso3", "country", "group", "treated_quarter"])
        for row in ROWS:
            w.writerow([row[0], row[1], row[2], row[3] or ""])
    print(f"wrote {len(ROWS)} rows to {OUT_PATH}")


if __name__ == "__main__":
    main()

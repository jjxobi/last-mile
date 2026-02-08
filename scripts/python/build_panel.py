"""
Joins the coverage-date table and the Ookla country-quarter aggregates into
one long panel, coded the way R's `did` package (Callaway & Sant'Anna)
expects: an integer time period, an integer id per unit, and a `gvar`
column giving the period a unit was first treated (0 for never-treated).
"""

from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
COVERAGE_PATH = ROOT / "data" / "processed" / "coverage_dates.csv"
OOKLA_PATH = ROOT / "data" / "processed" / "ookla_country_quarter.csv"
OUT_PATH = ROOT / "data" / "processed" / "panel.csv"

# sequential period index for 2022 Q1 .. 2024 Q4
PERIOD_INDEX = {
    (year, q): (year - 2022) * 4 + q
    for year in (2022, 2023, 2024)
    for q in (1, 2, 3, 4)
}


def main():
    coverage = pd.read_csv(COVERAGE_PATH)
    ookla = pd.read_csv(OOKLA_PATH)

    coverage["gvar"] = coverage.treated_quarter.apply(
        lambda tq: PERIOD_INDEX[(int(tq.split("-Q")[0]), int(tq.split("-Q")[1]))]
        if isinstance(tq, str) and tq
        else 0
    )

    ookla["period"] = ookla.apply(lambda r: PERIOD_INDEX[(int(r.year), int(r.quarter))], axis=1)

    panel = ookla.merge(coverage[["iso3", "country", "group", "gvar"]], on="iso3", how="left")

    if panel.country.isna().any():
        missing = panel[panel.country.isna()].iso3.unique()
        raise RuntimeError(f"ookla data has countries not in coverage_dates.csv: {missing}")

    panel["id"] = panel.iso3.astype("category").cat.codes + 1

    panel = panel.sort_values(["id", "period"]).reset_index(drop=True)

    cols = [
        "id", "iso3", "country", "group", "gvar", "period", "year", "quarter",
        "median_d_mbps", "mean_d_mbps_test_weighted", "median_u_mbps",
        "n_tiles", "n_tests", "n_devices",
    ]
    panel = panel[cols]
    panel.to_csv(OUT_PATH, index=False)
    print(f"wrote {len(panel)} rows ({panel.id.nunique()} units x up to {panel.period.nunique()} periods) to {OUT_PATH}")

    # sanity check: every unit should have all 12 periods
    counts = panel.groupby("iso3").size()
    incomplete = counts[counts != len(PERIOD_INDEX)]
    if len(incomplete):
        print("WARNING: incomplete panel for:")
        print(incomplete)


if __name__ == "__main__":
    main()

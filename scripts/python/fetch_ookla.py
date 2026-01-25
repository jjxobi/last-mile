"""
Pulls quarterly fixed-broadband performance tiles from Ookla's Open Data
bucket (public, no credentials needed) and aggregates down to
country-quarter medians for the six countries in the pilot panel.

The bucket holds one global parquet file per quarter, roughly 300-400MB
each and around 6-7 million tiles. Downloading and keeping all of them
would be a lot of disk for six countries' worth of signal, so each quarter
is downloaded, filtered down to the target countries, aggregated, and the
raw global file is deleted before moving to the next quarter.

Country membership is decided by a real point-in-polygon test against
Natural Earth admin-0 boundaries, not a bounding box, since several of the
target countries (Nigeria, Kenya especially) share long borders with
non-target countries and a bounding box would misattribute border tiles.
"""

import json
import shutil
import sys
import time
from pathlib import Path

import pandas as pd
import pyarrow.parquet as pq
import requests
from shapely.geometry import shape, Point
from shapely.strtree import STRtree
from shapely import wkt as shapely_wkt

ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "data" / "raw"
BOUNDARIES_PATH = RAW_DIR / "boundaries" / "ne_countries.geojson"
OUT_PATH = ROOT / "data" / "processed" / "ookla_country_quarter.csv"

TARGET_ISO3 = ["NGA", "PHL", "KEN", "IND", "VNM", "THA"]

QUARTERS = [
    (year, q)
    for year in (2022, 2023, 2024)
    for q in (1, 2, 3, 4)
]

QUARTER_TO_FILE_MONTH = {1: "01", 2: "04", 3: "07", 4: "10"}

BASE_URL = "https://ookla-open-data.s3.amazonaws.com/parquet/performance/type=fixed"


def load_target_polygons():
    with BOUNDARIES_PATH.open(encoding="utf-8") as f:
        gj = json.load(f)
    polygons = {}
    for feat in gj["features"]:
        iso3 = feat["properties"].get("ISO_A3") or feat["properties"].get("ADM0_A3")
        if iso3 in TARGET_ISO3:
            polygons[iso3] = shape(feat["geometry"])
    missing = set(TARGET_ISO3) - set(polygons)
    if missing:
        raise RuntimeError(f"missing boundaries for {missing}")
    return polygons


def download_quarter(year, q):
    month = QUARTER_TO_FILE_MONTH[q]
    fname = f"{year}-{month}-01_performance_fixed_tiles.parquet"
    url = f"{BASE_URL}/year={year}/quarter={q}/{fname}"
    dest = RAW_DIR / fname
    if dest.exists():
        print(f"  already have {fname}")
        return dest
    print(f"  downloading {url}")
    t0 = time.time()
    with requests.get(url, stream=True, timeout=600) as r:
        r.raise_for_status()
        with dest.open("wb") as f:
            shutil.copyfileobj(r.raw, f)
    print(f"  done in {time.time() - t0:.0f}s, {dest.stat().st_size / 1e6:.0f}MB")
    return dest


def bbox_prefilter(df, polygons):
    """Cheap bounding-box cut before the expensive per-row polygon test."""
    minx = min(p.bounds[0] for p in polygons.values())
    miny = min(p.bounds[1] for p in polygons.values())
    maxx = max(p.bounds[2] for p in polygons.values())
    maxy = max(p.bounds[3] for p in polygons.values())
    return df[
        (df.lon >= minx) & (df.lon <= maxx) & (df.lat >= miny) & (df.lat <= maxy)
    ]


def assign_country(df, polygons):
    tree = STRtree(list(polygons.values()))
    iso3_list = list(polygons.keys())
    geoms = list(polygons.values())

    assigned = [None] * len(df)
    points = [Point(lon, lat) for lon, lat in zip(df.lon.values, df.lat.values)]
    for i, pt in enumerate(points):
        idx_candidates = tree.query(pt)
        for idx in idx_candidates:
            geom = geoms[idx]
            if geom.contains(pt) or geom.intersects(pt):
                assigned[i] = iso3_list[idx]
                break
    df = df.copy()
    df["iso3"] = assigned
    return df[df.iso3.notna()]


def tile_centroid(tile_wkt):
    try:
        return shapely_wkt.loads(tile_wkt).centroid
    except Exception:
        return None


def process_quarter(year, q, polygons):
    path = download_quarter(year, q)
    print(f"  reading {path.name}")
    table = pq.read_table(path, columns=["tile", "avg_d_kbps", "avg_u_kbps", "tests", "devices"])
    df = table.to_pandas()

    centroids = df.tile.apply(tile_centroid)
    df = df[centroids.notna()]
    centroids = centroids[centroids.notna()]
    df["lon"] = centroids.apply(lambda p: p.x)
    df["lat"] = centroids.apply(lambda p: p.y)

    df = bbox_prefilter(df, polygons)
    print(f"  {len(df)} tiles in target bounding box, running point-in-polygon")
    df = assign_country(df, polygons)
    print(f"  {len(df)} tiles matched to target countries")

    df["d_mbps"] = df.avg_d_kbps / 1000.0
    df["u_mbps"] = df.avg_u_kbps / 1000.0

    def weighted(group):
        w = group.tests
        return pd.Series({
            "median_d_mbps": group.d_mbps.median(),
            "mean_d_mbps_test_weighted": (group.d_mbps * w).sum() / w.sum(),
            "median_u_mbps": group.u_mbps.median(),
            "n_tiles": len(group),
            "n_tests": int(w.sum()),
            "n_devices": int(group.devices.sum()),
        })

    agg = df.groupby("iso3").apply(weighted).reset_index()
    agg["year"] = year
    agg["quarter"] = q

    # free disk before the next quarter
    path.unlink()

    return agg


def main():
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    polygons = load_target_polygons()

    results = []
    if OUT_PATH.exists():
        existing = pd.read_csv(OUT_PATH)
        done = set(zip(existing.year, existing.quarter))
        results.append(existing)
    else:
        done = set()

    for year, q in QUARTERS:
        if (year, q) in done:
            print(f"{year} Q{q}: already in output, skipping")
            continue
        print(f"{year} Q{q}:")
        agg = process_quarter(year, q, polygons)
        results.append(agg)
        combined = pd.concat(results, ignore_index=True)
        combined.to_csv(OUT_PATH, index=False)
        print(f"  wrote running total ({len(combined)} rows) to {OUT_PATH}")

    print("done")


if __name__ == "__main__":
    sys.exit(main())

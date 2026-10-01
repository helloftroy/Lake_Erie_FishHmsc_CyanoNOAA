"""Extract NOAA Cyanobacteria Index (CI) at every Lake Erie conventional fish
station x year, 2006-2024 (the years for which we have both fish data and CI
imagery). CI is NOT available for Ontario/Superior in NOAA's archive, and the
Huron/Michigan products are hard-masked to Saginaw Bay/Green Bay only — a
direct pixel check confirmed 0/309 Huron and 0/274 Michigan fish stations
fall on a valid pixel, so those two lakes are reported as unavailable rather
than silently skipped.

Products used (single product per year to avoid cross-sensor calibration
mixing within a year):
  2006-2015: MODIS-CyanNet gap-filler (1km, Albers, continuous 2000-2018)
  2016-2024: OLCI (300m, UTM17N) — native highest-resolution product

Per station-year (station = fish event coords rounded to 3 decimals, ~111m,
matched to satellite pixel scale):
  season_max_CI       = max valid CI pixel value across all that year's
                         June-Nov 10-day composites at that station
  season_median_CI    = median of valid composite values that year
  season_cumulative_CI = sum of valid composite values that year (standard
                         cumulative bloom-exposure metric)
  bloom_detected       = any composite that year with CI > 42 (the
                         NOAA-documented bloom detection threshold, docs:
                         DN>42 ~ 20,000 cells/mL)
  n_valid_composites   = how many of that year's composites had a valid
                         (non-cloud/non-nodata) pixel at that station —
                         low N means the summary is based on sparse looks.

Outputs:
  processed/ci_station_year.csv      -- per station-year detail
  processed/ci_lake_subbasin_summary.csv -- the requested summary table
"""
import re
from pathlib import Path

import numpy as np
import pandas as pd
import rasterio
from rasterio.warp import transform

RAW = Path(__file__).parent.parent / "raw/noaa_ci/erie"
OUT = Path(__file__).parent.parent / "processed"
BLOOM_THRESHOLD = 42

FNAME_RE_MODIS = re.compile(r"CyanNet_(\d{4})\.(\d{4})_(\d{4})")
FNAME_RE_OLCI = re.compile(r"ts_(\d{4})\.(\d{4})_(\d{4})")


def parse_year(path, is_olci):
    m = (FNAME_RE_OLCI if is_olci else FNAME_RE_MODIS).search(path.name)
    return int(m.group(1)) if m else None


def western_basin_subbasin(lon):
    """Erie CI signal is essentially western-basin-only (see notebook check:
    >90% of valid pixels fall west of -83 deg lon). Tag stations so the
    summary can show this honestly rather than diluting it across the whole
    lake's station count."""
    if lon <= -82.5:
        return "Western Basin"
    elif lon <= -81.0:
        return "Central Basin"
    else:
        return "Eastern Basin"


def main():
    conv = pd.read_csv(OUT / "conventional_events.csv")
    conv["date"] = pd.to_datetime(conv["date"], errors="coerce")
    erie = conv[(conv.lake == "Lake Erie") & conv.date.notna()].copy()
    erie["year"] = erie["date"].dt.year
    erie = erie[(erie.year >= 2006) & (erie.year <= 2024)]
    erie["lat_r"] = erie["lat"].round(3)
    erie["lon_r"] = erie["lon"].round(3)
    erie["subbasin"] = erie["lon"].apply(western_basin_subbasin)

    stations = erie[["lat_r", "lon_r"]].drop_duplicates().reset_index(drop=True)
    print(f"{len(erie)} dated Lake Erie events, 2006-2024; {len(stations)} unique stations (0.001deg rounding)")

    # per (station, year, file) raw extracted values
    records = []
    files = sorted((RAW / "modis").glob("*.tif")) + sorted((RAW / "olci").glob("*.tif"))
    for i, f in enumerate(files):
        is_olci = "olci" in str(f.parent)
        yr = parse_year(f, is_olci)
        if yr is None:
            continue
        yr_stations = erie.loc[erie.year == yr, ["lat_r", "lon_r"]].drop_duplicates()
        if yr_stations.empty:
            continue
        with rasterio.open(f) as src:
            xs, ys = transform("EPSG:4326", src.crs, yr_stations.lon_r.tolist(), yr_stations.lat_r.tolist())
            vals = np.array([v[0] for v in src.sample(zip(xs, ys))])
        for (lat_r, lon_r), v in zip(yr_stations.itertuples(index=False), vals):
            if v <= 250:
                records.append({"lat_r": lat_r, "lon_r": lon_r, "year": yr, "ci": int(v)})
        if (i + 1) % 100 == 0:
            print(f"  processed {i+1}/{len(files)} rasters...")

    raw_vals = pd.DataFrame(records)
    raw_vals.to_csv(OUT / "ci_raw_extracted_values.csv", index=False)
    print(f"{len(raw_vals)} valid (station, year, composite) extractions")

    # ---- per station-year summary
    sy = (raw_vals.groupby(["lat_r", "lon_r", "year"])
          .agg(season_max_CI=("ci", "max"), season_median_CI=("ci", "median"),
               season_cumulative_CI=("ci", "sum"), n_valid_composites=("ci", "size"),
               bloom_detected=("ci", lambda s: bool((s > BLOOM_THRESHOLD).any())))
          .reset_index())
    sy["subbasin"] = sy["lon_r"].apply(western_basin_subbasin)

    # attach fish-event counts per station-year (from ALL Erie events at that
    # rounded station/year, not just the ones with valid CI — so we can also
    # see how many station-years had fish data but NO usable CI)
    events_per_sy = (erie.groupby(["lat_r", "lon_r", "year"]).size()
                      .reset_index(name="fish_events_at_station_year"))
    sy_full = events_per_sy.merge(sy, on=["lat_r", "lon_r", "year"], how="left")
    sy_full["subbasin"] = sy_full["lon_r"].apply(western_basin_subbasin)
    sy_full.to_csv(OUT / "ci_station_year.csv", index=False)

    print(f"\n{len(sy_full)} total station-years with fish data (2006-2024); "
          f"{sy_full.season_max_CI.notna().sum()} have at least one valid CI extraction "
          f"({100*sy_full.season_max_CI.notna().mean():.1f}%)")

    # ---- requested summary table, by lake/sub-basin
    rows = []
    for subbasin, g in sy_full.groupby("subbasin"):
        ev = erie[erie["lon_r"].apply(western_basin_subbasin) == subbasin]
        with_ci = g[g.season_max_CI.notna()]
        rows.append({
            "lake_subbasin": f"Lake Erie - {subbasin}",
            "fish_events": len(ev),
            "unique_stations": ev[["lat_r", "lon_r"]].drop_duplicates().shape[0],
            "years": f"{int(ev.year.min())}-{int(ev.year.max())} ({ev.year.nunique()} yrs)",
            "station_years_with_CI": len(with_ci),
            "station_years_total": len(g),
            "pct_station_years_with_CI": round(100 * len(with_ci) / len(g), 1) if len(g) else np.nan,
            "median_CI": with_ci.season_median_CI.median() if len(with_ci) else np.nan,
            "max_CI": with_ci.season_max_CI.max() if len(with_ci) else np.nan,
            "pct_station_years_with_detectable_bloom": round(100 * with_ci.bloom_detected.mean(), 1) if len(with_ci) else np.nan,
            "cumulative_CI_variance": with_ci.season_cumulative_CI.var() if len(with_ci) > 1 else np.nan,
        })
    summary = pd.DataFrame(rows)
    summary.to_csv(OUT / "ci_lake_subbasin_summary.csv", index=False)

    pd.set_option("display.max_columns", None)
    pd.set_option("display.width", 220)
    print("\n" + summary.to_string(index=False))


if __name__ == "__main__":
    main()

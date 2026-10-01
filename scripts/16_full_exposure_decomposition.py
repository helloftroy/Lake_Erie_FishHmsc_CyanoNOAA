"""All 82 real WB-trawl stations x 2013-2024: build the full CI exposure
table (5km buffer, same recipe as the 6-station pilot), then:

(1) Classify each station inside/middle/outside the bloom based on its
    bloom-detection rate (fraction of station-years where any bloom-season
    composite in its 5km buffer exceeded NOAA's own threshold, DN>42).

(2) Fit exposure ~ (1|station) + (1|year) as a crossed-random-effects model
    (statsmodels MixedLM with two variance components, no fixed effects
    beyond the intercept) and report the variance share for station, year,
    and residual — plus a literal "bloom days" translation of the residual
    SD using a secondary response (count of 10-day bloom-positive composites
    per station-year).

Outputs:
  processed/ci_exposure_all_stations.csv
  processed/station_bloom_classification.csv
  figures/station_bloom_classification_map.png
"""
import re
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import rasterio
import statsmodels.formula.api as smf
from rasterio.warp import transform
from rasterio.windows import from_bounds

RAW_CI = Path(__file__).parent.parent / "raw/noaa_ci/erie"
RAW_FISH = Path(__file__).parent.parent / "raw/lake_erie"
OUT = Path(__file__).parent.parent / "processed"
FIG = Path(__file__).parent.parent / "figures"
BUFFER_KM = 5
BLOOM_THRESHOLD = 42
_DATE_RE = re.compile(r"_(\d{4})\.(\d{4})_(\d{4})")


def composite_files_for_year(year):
    if year <= 2015:
        return sorted(RAW_CI.glob(f"modis/ts.Terra.CyanNet_{year}.*.tif"))
    return sorted(RAW_CI.glob(f"olci/ts_{year}.*.tif"))


def bloom_season_only(files):
    out = []
    for f in files:
        m = _DATE_RE.search(f.name)
        if m and 6 <= int(m.group(2)[:2]) <= 11:
            out.append(f)
    return out


def get_stations():
    d = pd.read_csv(RAW_FISH / "WB_Catch_2013_2025.csv", low_memory=False)
    g = d.groupby("serial").agg(lat=("lat", "mean"), lon=("long", "mean"), n_years=("year", "nunique")).reset_index()
    g["dist_km"] = np.sqrt((g.lat - 41.7) ** 2 * 111 ** 2 +
                            (g.lon + 83.3) ** 2 * (111 * np.cos(np.radians(41.7))) ** 2)
    return g[g.n_years >= 9].reset_index(drop=True)  # all 82 qualify per prior check


def main():
    stations = get_stations()
    print(f"{len(stations)} stations")

    buf_m = BUFFER_KM * 1000
    records = []
    for year in range(2013, 2025):
        files = bloom_season_only(composite_files_for_year(year))
        per_station_vals = {sid: [] for sid in stations.serial}
        per_station_bloom = {sid: 0 for sid in stations.serial}
        for f in files:
            with rasterio.open(f) as src:
                xs, ys = transform("EPSG:4326", src.crs, stations.lon.tolist(), stations.lat.tolist())
                for sid, x, y in zip(stations.serial, xs, ys):
                    try:
                        window = from_bounds(x - buf_m, y - buf_m, x + buf_m, y + buf_m, src.transform)
                        arr = src.read(1, window=window)
                    except Exception:
                        continue
                    valid = arr[arr <= 250]
                    if valid.size:
                        m = float(valid.mean())
                        per_station_vals[sid].append(m)
                        if valid.max() > BLOOM_THRESHOLD:
                            per_station_bloom[sid] += 1
        for sid in stations.serial:
            vals = per_station_vals[sid]
            records.append({
                "serial": sid, "year": year,
                "n_composites_valid": len(vals),
                "cumulative_CI": sum(vals) if vals else np.nan,
                "n_bloom_composites": per_station_bloom[sid],
                "any_bloom": per_station_bloom[sid] > 0,
            })
        print(f"  year {year}: {len(files)} composites processed")

    df = pd.DataFrame(records).merge(stations[["serial", "lat", "lon", "dist_km"]], on="serial")
    df.to_csv(OUT / "ci_exposure_all_stations.csv", index=False)

    # ---------------------------------------------------- (1) bloom classification
    cls = df.groupby("serial").agg(
        n_years=("year", "count"), n_years_with_bloom=("any_bloom", "sum"),
        dist_km=("dist_km", "first"), lat=("lat", "first"), lon=("lon", "first"),
        mean_cum_CI=("cumulative_CI", "mean"),
    ).reset_index()
    cls["bloom_rate"] = cls.n_years_with_bloom / cls.n_years
    cls["zone"] = pd.cut(cls.bloom_rate, bins=[-0.01, 0.2, 0.8, 1.01],
                          labels=["outside", "middle", "inside"])
    cls.to_csv(OUT / "station_bloom_classification.csv", index=False)

    print("\n" + "=" * 70)
    print("Station bloom-zone classification (bloom_rate = fraction of years with >=1 "
          f"composite in 5km buffer exceeding CI>{BLOOM_THRESHOLD}):")
    print(cls.zone.value_counts())
    print()
    print(cls.groupby("zone")[["dist_km", "bloom_rate", "mean_cum_CI"]].mean())

    # map
    fig, ax = plt.subplots(figsize=(8, 7))
    colors = {"inside": "#D55E00", "middle": "#E69F00", "outside": "#0072B2"}
    for zone, g in cls.groupby("zone", observed=True):
        ax.scatter(g.lon, g.lat, s=60, c=colors[zone], label=f"{zone} (n={len(g)})", edgecolors="black", linewidths=0.5)
    ax.set_xlabel("Longitude")
    ax.set_ylabel("Latitude")
    ax.set_title(f"WB-trawl station bloom-zone classification (n={len(cls)})\n"
                 f"inside: bloom detected >80% of years | middle: 20-80% | outside: <20%")
    ax.legend()
    ax.grid(alpha=0.3)
    fig.tight_layout()
    fig.savefig(FIG / "station_bloom_classification_map.png", dpi=150)
    plt.close(fig)

    # ---------------------------------------------------- (2) crossed variance decomposition
    print("\n" + "=" * 70)
    print("Two-way crossed random-effects decomposition: cumulative_CI ~ (1|station) + (1|year)")
    fit_df = df.dropna(subset=["cumulative_CI"]).copy()
    fit_df["grp"] = 1  # single dummy group; station & year enter as crossed variance components
    model = smf.mixedlm("cumulative_CI ~ 1", data=fit_df, groups=fit_df["grp"],
                         vc_formula={"station": "0 + C(serial)", "year": "0 + C(year)"})
    result = model.fit(reml=True)

    var_station = result.vcomp[0] if "station Var" in str(result.cov_re) or True else None
    # statsmodels stores variance components in result.vcomp in the order of vc_formula dict
    vc_names = list(model.exog_vc.names)
    vcomp = dict(zip(vc_names, result.vcomp))
    resid_var = result.scale
    total_var = sum(vcomp.values()) + resid_var

    print(f"Station variance: {vcomp.get('station', float('nan')):.2f} "
          f"({100*vcomp.get('station',0)/total_var:.1f}% of total)")
    print(f"Year variance:    {vcomp.get('year', float('nan')):.2f} "
          f"({100*vcomp.get('year',0)/total_var:.1f}% of total)")
    print(f"Residual variance: {resid_var:.2f} ({100*resid_var/total_var:.1f}% of total)")
    print(f"Residual SD: {resid_var**0.5:.1f} cumulative-CI units "
          f"({100*resid_var**0.5/fit_df.cumulative_CI.mean():.1f}% of grand mean {fit_df.cumulative_CI.mean():.1f})")

    # secondary: same decomposition on n_bloom_composites (directly interpretable as ~10-day bloom periods)
    print("\nSame decomposition on n_bloom_composites (each unit ~= one 10-day bloom-positive period):")
    model2 = smf.mixedlm("n_bloom_composites ~ 1", data=fit_df, groups=fit_df["grp"],
                          vc_formula={"station": "0 + C(serial)", "year": "0 + C(year)"})
    result2 = model2.fit(reml=True)
    vcomp2 = dict(zip(vc_names, result2.vcomp))
    resid_var2 = result2.scale
    total_var2 = sum(vcomp2.values()) + resid_var2
    print(f"Station variance: {vcomp2.get('station',0):.3f} ({100*vcomp2.get('station',0)/total_var2:.1f}%)")
    print(f"Year variance:    {vcomp2.get('year',0):.3f} ({100*vcomp2.get('year',0)/total_var2:.1f}%)")
    print(f"Residual variance: {resid_var2:.3f} ({100*resid_var2/total_var2:.1f}%)")
    print(f"Residual SD: {resid_var2**0.5:.2f} bloom-positive 10-day periods "
          f"(~{resid_var2**0.5*10:.0f} days), grand mean n_bloom_composites={fit_df.n_bloom_composites.mean():.2f}")


if __name__ == "__main__":
    main()

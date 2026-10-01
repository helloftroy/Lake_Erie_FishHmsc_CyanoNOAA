"""Before building anything: is CI exposure mostly a fixed SITE effect
(same stations bloom every year, others never do -> site FE swallows it,
effectively n = n_sites) or does it vary meaningfully WITHIN a site across
years (the design has real degrees of freedom)?

Uses 6 real, fixed WB-trawl station IDs (serial numbers, not random points)
spanning ~10-90km from the Maumee River mouth, each sampled 10-13 of
2013-2025. CI exposure computed per station-year (5km buffer, per the prior
buffer test showing 5km meaningfully rescues coverage vs point extraction),
for years 2013-2024 (CI archive ends 2024).

Output: processed/ci_exposure_site_year.csv, figures/ci_exposure_site_year.png
"""
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import rasterio
from rasterio.warp import transform
from rasterio.windows import from_bounds

RAW_CI = Path(__file__).parent.parent / "raw/noaa_ci/erie"
OUT = Path(__file__).parent.parent / "processed"
FIG = Path(__file__).parent.parent / "figures"
BUFFER_KM = 5

# 6 fixed WB-trawl stations spanning near->far from the Maumee mouth
STATIONS = {
    102: (41.778250, -83.245880, 9.8),
    504: (41.683254, -83.150154, 12.6),
    509: (41.777769, -83.047531, 22.6),
    514: (41.763592, -82.945238, 30.2),
    521: (41.681246, -82.749908, 45.6),
    541: (41.478650, -82.262933, 89.4),
}


def composite_files_for_year(year):
    if year <= 2015:
        return sorted(RAW_CI.glob(f"modis/ts.Terra.CyanNet_{year}.*.tif"))
    else:
        return sorted(RAW_CI.glob(f"olci/ts_{year}.*.tif"))


import re
_DATE_RE = re.compile(r"_(\d{4})\.(\d{4})_(\d{4})")


def bloom_season_only(files):
    out = []
    for f in files:
        m = _DATE_RE.search(f.name)
        if not m:
            continue
        month = int(m.group(2)[:2])
        if 6 <= month <= 11:
            out.append(f)
    return out


def main():
    rows = []
    for serial, (lat, lon, dist_km) in STATIONS.items():
        for year in range(2013, 2025):
            files = bloom_season_only(composite_files_for_year(year))
            vals = []
            for f in files:
                with rasterio.open(f) as src:
                    x, y = transform("EPSG:4326", src.crs, [lon], [lat])
                    buf_m = BUFFER_KM * 1000
                    try:
                        window = from_bounds(x[0] - buf_m, y[0] - buf_m, x[0] + buf_m, y[0] + buf_m, src.transform)
                        arr = src.read(1, window=window)
                    except Exception:
                        continue
                    valid = arr[arr <= 250]
                    if valid.size:
                        vals.append(float(valid.mean()))
            rows.append({
                "serial": serial, "lat": lat, "lon": lon, "dist_km": dist_km, "year": year,
                "n_composites_total": len(files), "n_composites_valid": len(vals),
                "cumulative_CI": sum(vals) if vals else np.nan,
                "max_CI": max(vals) if vals else np.nan,
                "mean_CI": np.mean(vals) if vals else np.nan,
            })
        print(f"done serial {serial} ({dist_km}km)")

    df = pd.DataFrame(rows)
    df.to_csv(OUT / "ci_exposure_site_year.csv", index=False)

    # ---- variance decomposition (on cumulative_CI, treating missing years as NaN/excluded)
    print("\n" + "=" * 70)
    print("Per-station: years with valid CI, mean/std of cumulative_CI across years")
    summary = df.groupby(["serial", "dist_km"]).agg(
        n_years_with_data=("cumulative_CI", lambda s: s.notna().sum()),
        mean_cum_CI=("cumulative_CI", "mean"), std_cum_CI=("cumulative_CI", "std"),
        min_cum_CI=("cumulative_CI", "min"), max_cum_CI=("cumulative_CI", "max"),
    ).reset_index()
    print(summary.to_string(index=False))

    valid = df.dropna(subset=["cumulative_CI"])
    grand_mean = valid.cumulative_CI.mean()
    site_means = valid.groupby("serial").cumulative_CI.mean()
    n_per_site = valid.groupby("serial").cumulative_CI.count()

    # between-site variance (variance of site means, weighted)
    between_var = np.average((site_means - grand_mean) ** 2, weights=n_per_site)
    # within-site variance (pooled, averaged across sites)
    within_var = valid.groupby("serial").cumulative_CI.var(ddof=0).mean()

    icc = between_var / (between_var + within_var) if (between_var + within_var) > 0 else np.nan
    print(f"\nBetween-site variance (of site means): {between_var:.2f}")
    print(f"Within-site variance (avg across years, per site): {within_var:.2f}")
    print(f"ICC (between / (between+within)): {icc:.3f}")
    print("  ICC near 1.0 = exposure is basically a fixed site effect (bad for design: n collapses to n_sites)")
    print("  ICC near 0.0-0.5 = real year-to-year variation within sites (good: station-years carry real info)")

    # ---- plot
    fig, ax = plt.subplots(figsize=(10, 6))
    colors = plt.cm.viridis(np.linspace(0, 1, len(STATIONS)))
    for (serial, (lat, lon, dist_km)), c in zip(STATIONS.items(), colors):
        sub = df[df.serial == serial].sort_values("year")
        ax.plot(sub.year, sub.cumulative_CI, marker="o", color=c, label=f"serial {serial} ({dist_km}km from mouth)")
    ax.set_xlabel("Year")
    ax.set_ylabel("Cumulative CI (5km buffer, bloom season sum)")
    ax.set_title("CI exposure by year, 6 fixed WB-trawl stations\n"
                 "(crossing lines = real within-site variation; parallel flat lines = pure site effect)")
    ax.legend(fontsize=8, loc="upper left")
    ax.grid(alpha=0.3)
    fig.tight_layout()
    fig.savefig(FIG / "ci_exposure_site_year.png", dpi=150)
    plt.close(fig)
    print("\nSaved figures/ci_exposure_site_year.png")


if __name__ == "__main__":
    main()

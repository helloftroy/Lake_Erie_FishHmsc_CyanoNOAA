"""Check whether the 82 WB-trawl fish stations were sampled evenly across
years and against each other -- i.e. is the variance decomposition at risk
of being driven by a handful of over/under-sampled stations?

Outputs:
  figures/sampling_balance_heatmap.png   -- station x year, sampled or not
  figures/sampling_balance_per_station.png -- total events per station, by zone
  figures/sampling_balance_per_year.png  -- total stations sampled per year
"""
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

RAW = Path(__file__).parent.parent / "raw/lake_erie"
OUT = Path(__file__).parent.parent / "processed"
FIG = Path(__file__).parent.parent / "figures"

ZONE_COLORS = {"inside": "#D55E00", "middle": "#E69F00", "outside": "#0072B2"}


def main():
    d = pd.read_csv(RAW / "WB_Catch_2013_2025.csv", low_memory=False)
    events = d[["serial", "year", "month", "day"]].drop_duplicates()
    cls = pd.read_csv(OUT / "station_bloom_classification.csv")

    # ---- station x year presence grid
    pivot = events.groupby(["serial", "year"]).size().unstack(fill_value=0)
    all_years = list(range(2013, 2026))
    pivot = pivot.reindex(columns=all_years, fill_value=0)

    # order stations by zone then by distance for a readable heatmap
    zone_order = {"inside": 0, "middle": 1, "outside": 2}
    cls_sorted = cls.copy()
    cls_sorted["zone_rank"] = cls_sorted.zone.map(zone_order)
    cls_sorted = cls_sorted.sort_values(["zone_rank", "dist_km"])
    station_order = [s for s in cls_sorted.serial if s in pivot.index]
    pivot = pivot.reindex(index=station_order)

    fig, ax = plt.subplots(figsize=(10, 14))
    im = ax.imshow(pivot.to_numpy(), cmap="Greys", aspect="auto", vmin=0, vmax=1)
    ax.set_xticks(range(len(all_years)))
    ax.set_xticklabels(all_years, rotation=45)
    ax.set_yticks(range(len(station_order)))
    ax.set_yticklabels(station_order, fontsize=6)
    # color-code the station labels by zone
    zone_map = dict(zip(cls.serial, cls.zone))
    for tick, sid in zip(ax.get_yticklabels(), station_order):
        tick.set_color(ZONE_COLORS.get(zone_map.get(sid), "black"))
    ax.set_xlabel("Year")
    ax.set_ylabel("Station (serial), grouped inside→middle→outside, sorted by distance within group")
    ax.set_title("Fish-survey sampling presence: station x year (2013-2025)\n"
                 "black = sampled that year, white = not sampled; label color = bloom zone")
    fig.tight_layout()
    fig.savefig(FIG / "sampling_balance_heatmap.png", dpi=150)
    plt.close(fig)

    # ---- total events per station, sorted, colored by zone
    totals = events.groupby("serial").size().reindex(cls_sorted.serial).reset_index(name="n_events")
    totals = totals.merge(cls[["serial", "zone"]], on="serial")
    totals = totals.sort_values("n_events")

    fig, ax = plt.subplots(figsize=(14, 5))
    colors = [ZONE_COLORS[z] for z in totals.zone]
    ax.bar(range(len(totals)), totals.n_events, color=colors)
    ax.set_xticks(range(len(totals)))
    ax.set_xticklabels(totals.serial, rotation=90, fontsize=6)
    ax.set_xlabel("Station (serial), sorted by total events")
    ax.set_ylabel("Total sampling events, 2013-2025")
    ax.set_title(f"Total fish-survey events per station (n=82 stations, range {totals.n_events.min()}-{totals.n_events.max()})")
    ax.axhline(totals.n_events.median(), color="black", linestyle="--", linewidth=1, label=f"median={totals.n_events.median():.0f}")
    handles = [plt.Rectangle((0, 0), 1, 1, color=c) for c in ZONE_COLORS.values()]
    ax.legend(handles + [plt.Line2D([0], [0], color="black", linestyle="--")],
              list(ZONE_COLORS.keys()) + ["median"], loc="upper left")
    fig.tight_layout()
    fig.savefig(FIG / "sampling_balance_per_station.png", dpi=150)
    plt.close(fig)

    # ---- total stations sampled per year
    per_year = events.groupby("year").serial.nunique().reindex(all_years, fill_value=0)
    fig, ax = plt.subplots(figsize=(9, 5))
    ax.bar(per_year.index, per_year.values, color="#0072B2")
    ax.set_xlabel("Year")
    ax.set_ylabel("N stations sampled")
    ax.set_title(f"N WB-trawl stations sampled per year (of 82 total; range {per_year[per_year>0].min()}-{per_year.max()})")
    ax.axhline(82, color="gray", linestyle=":", linewidth=1, label="all 82 stations")
    ax.legend()
    fig.tight_layout()
    fig.savefig(FIG / "sampling_balance_per_year.png", dpi=150)
    plt.close(fig)

    # ---- printed summary
    print("Per-station-year visit count check:")
    vy = events.groupby(["serial", "year"]).size()
    print(f"  max visits in any single station-year: {vy.max()} (1 = no within-year replication anywhere)")
    print()
    print("Total events per station: min={}, median={}, max={}".format(
        totals.n_events.min(), totals.n_events.median(), totals.n_events.max()))
    print()
    print("By zone:")
    print(totals.groupby("zone")["n_events"].agg(["count", "min", "median", "max"]))
    print()
    print("Stations sampled per year:")
    print(per_year)
    print()
    print("Years per station (coverage completeness):")
    yrs_per_station = events.groupby("serial").year.nunique()
    print(f"  min={yrs_per_station.min()}, median={yrs_per_station.median()}, max={yrs_per_station.max()}, "
          f"out of 13 possible years (2013-2025)")


if __name__ == "__main__":
    main()

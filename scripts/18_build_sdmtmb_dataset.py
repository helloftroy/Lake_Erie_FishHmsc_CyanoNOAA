"""Build the full modeling dataset for sdmTMB: western Lake Erie WB-trawl
events x 4 target species, with:
  - response: total ('ALL' life-stage) count per species per event
  - effort offset: log(area_m2) (swept area of the trawl)
  - temperature: near-surface temp_mean from the paired water-quality cast
  - exposure: bloom-days this season (n_bloom_composites*10, from the CI
    extraction) AND lag-1 (same station, previous year) -- two separate
    terms, not summed, so the model can estimate each lag's effect
    independently
  - coverage flags: adequate_current / adequate_lag1 (>=3 valid composites
    that station-year, matching the Part C coverage convention already
    established) so thin-coverage station-years can be filtered explicitly
    rather than silently treated as "no bloom"

Output: processed/sdmtmb_input.csv
"""
from pathlib import Path

import numpy as np
import pandas as pd

RAW = Path(__file__).parent.parent / "raw/lake_erie"
OUT = Path(__file__).parent.parent / "processed"

TARGET_SPECIES = {
    "Yellow Perch": "count_yellow_perch",
    "Walleye": "count_walleye",
    "White Perch": "count_white_perch",
    "Emerald Shiner": "count_emerald_shiner",
}
MIN_VALID_COMPOSITES = 3  # coverage-adequacy bar, consistent with Part C convention


def main():
    catch = pd.read_csv(RAW / "WB_Catch_2013_2025.csv", low_memory=False)

    # ---- event table (one row per trawl event)
    events = catch[["serial", "lat", "long", "year", "month", "day", "area_m2"]].drop_duplicates(
        subset=["serial", "year", "month", "day"])
    print(f"{len(events)} unique trawl events")

    # ---- response: total ('ALL') count per species, pivoted wide
    sp = catch[(catch.life_stage == "ALL") & (catch.species.isin(TARGET_SPECIES))]
    wide = sp.pivot_table(index=["serial", "year", "month", "day"], columns="species",
                           values="count", aggfunc="sum", fill_value=0).reset_index()
    wide = wide.rename(columns=TARGET_SPECIES)
    for col in TARGET_SPECIES.values():
        if col not in wide.columns:
            wide[col] = 0

    df = events.merge(wide, on=["serial", "year", "month", "day"], how="left")
    for col in TARGET_SPECIES.values():
        df[col] = df[col].fillna(0).astype(int)

    # ---- temperature: near-surface bin from the paired water-quality cast
    wq = pd.read_csv(RAW / "WB_WaterQuality_2013_2025.csv", low_memory=False)
    wq_surf = (wq.sort_values("bin_depth_min")
               .groupby(["serial", "year"], as_index=False).first()[["serial", "year", "temp_mean"]]
               .rename(columns={"temp_mean": "surface_temp"}))
    df = df.merge(wq_surf, on=["serial", "year"], how="left")
    print(f"Temperature matched for {df.surface_temp.notna().sum()}/{len(df)} events")

    # ---- CI exposure: current season + lag-1 (same station, previous year)
    ci = pd.read_csv(OUT / "ci_exposure_all_stations.csv")
    ci["bloom_days"] = ci["n_bloom_composites"] * 10
    ci["adequate"] = ci["n_composites_valid"] >= MIN_VALID_COMPOSITES

    ci_cur = ci[["serial", "year", "bloom_days", "adequate"]].rename(
        columns={"bloom_days": "bloom_days_current", "adequate": "adequate_current"})
    df = df.merge(ci_cur, on=["serial", "year"], how="left")

    ci_lag = ci[["serial", "year", "bloom_days", "adequate"]].copy()
    ci_lag["year"] = ci_lag["year"] + 1  # shift so it joins onto the FOLLOWING year
    ci_lag = ci_lag.rename(columns={"bloom_days": "bloom_days_lag1", "adequate": "adequate_lag1"})
    df = df.merge(ci_lag, on=["serial", "year"], how="left")

    df = df.rename(columns={"long": "lon"})
    df.to_csv(OUT / "sdmtmb_input.csv", index=False)

    print(f"\nFinal dataset: {len(df)} rows")
    print(f"  surface_temp available: {df.surface_temp.notna().sum()} ({100*df.surface_temp.notna().mean():.1f}%)")
    print(f"  bloom_days_current available: {df.bloom_days_current.notna().sum()} "
          f"({100*df.bloom_days_current.notna().mean():.1f}%), of which adequate coverage: "
          f"{df.adequate_current.sum()}")
    print(f"  bloom_days_lag1 available: {df.bloom_days_lag1.notna().sum()} "
          f"({100*df.bloom_days_lag1.notna().mean():.1f}%), of which adequate coverage: "
          f"{df.adequate_lag1.sum()}")
    complete = df.dropna(subset=["surface_temp", "bloom_days_current", "bloom_days_lag1"])
    complete_adequate = complete[complete.adequate_current & complete.adequate_lag1]
    print(f"\n  Rows with ALL fields present (no NA): {len(complete)}")
    print(f"  Rows with all fields present AND adequate CI coverage (current+lag1): {len(complete_adequate)}")
    print(f"  Years spanned by the adequate-coverage subset: "
          f"{sorted(complete_adequate.year.unique())}")
    print(f"  Unique stations in the adequate-coverage subset: {complete_adequate.serial.nunique()}")

    for col in TARGET_SPECIES.values():
        print(f"  {col}: total={df[col].sum()}, n events with catch>0={ (df[col]>0).sum()}/{len(df)}")


if __name__ == "__main__":
    main()

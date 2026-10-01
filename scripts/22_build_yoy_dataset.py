"""YOY (age-0 / recruitment) counts for the 4 target species, same event
and covariate structure as the main 'ALL' dataset -- just swap the
life_stage filter. Reuses the same temperature/CI exposure joins.
"""
from pathlib import Path

import pandas as pd

RAW = Path(__file__).parent.parent / "raw/lake_erie"
OUT = Path(__file__).parent.parent / "processed"

TARGET_SPECIES = {
    "Yellow Perch": "yoy_yellow_perch",
    "Walleye": "yoy_walleye",
    "White Perch": "yoy_white_perch",
    "Emerald Shiner": "yoy_emerald_shiner",
}
MIN_VALID_COMPOSITES = 3


def main():
    catch = pd.read_csv(RAW / "WB_Catch_2013_2025.csv", low_memory=False)
    events = catch[["serial", "lat", "long", "year", "month", "day", "area_m2"]].drop_duplicates(
        subset=["serial", "year", "month", "day"])

    sp = catch[(catch.life_stage == "YOY") & (catch.species.isin(TARGET_SPECIES))]
    wide = sp.pivot_table(index=["serial", "year", "month", "day"], columns="species",
                           values="count", aggfunc="sum", fill_value=0).reset_index()
    wide = wide.rename(columns=TARGET_SPECIES)
    for col in TARGET_SPECIES.values():
        if col not in wide.columns:
            wide[col] = 0

    df = events.merge(wide, on=["serial", "year", "month", "day"], how="left")
    for col in TARGET_SPECIES.values():
        df[col] = df[col].fillna(0).astype(int)

    wq = pd.read_csv(RAW / "WB_WaterQuality_2013_2025.csv", low_memory=False)
    wq_surf = (wq.sort_values("bin_depth_min")
               .groupby(["serial", "year"], as_index=False).first()[["serial", "year", "temp_mean"]]
               .rename(columns={"temp_mean": "surface_temp"}))
    df = df.merge(wq_surf, on=["serial", "year"], how="left")

    ci = pd.read_csv(OUT / "ci_exposure_all_stations.csv")
    ci["bloom_days"] = ci["n_bloom_composites"] * 10
    ci["adequate"] = ci["n_composites_valid"] >= MIN_VALID_COMPOSITES
    ci_cur = ci[["serial", "year", "bloom_days", "adequate"]].rename(
        columns={"bloom_days": "bloom_days_current", "adequate": "adequate_current"})
    df = df.merge(ci_cur, on=["serial", "year"], how="left")
    ci_lag = ci[["serial", "year", "bloom_days", "adequate"]].copy()
    ci_lag["year"] = ci_lag["year"] + 1
    ci_lag = ci_lag.rename(columns={"bloom_days": "bloom_days_lag1", "adequate": "adequate_lag1"})
    df = df.merge(ci_lag, on=["serial", "year"], how="left")

    df = df.rename(columns={"long": "lon"})
    df.to_csv(OUT / "sdmtmb_input_yoy.csv", index=False)

    complete = df.dropna(subset=["surface_temp", "bloom_days_current", "bloom_days_lag1"])
    complete_adequate = complete[complete.adequate_current & complete.adequate_lag1]
    print(f"YOY dataset: {len(df)} total, {len(complete_adequate)} complete+adequate rows")
    for col in TARGET_SPECIES.values():
        print(f"  {col}: total={df[col].sum()}, n events with catch>0={(df[col]>0).sum()}/{len(df)}")


if __name__ == "__main__":
    main()

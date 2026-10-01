# Methods & Results Log

Running log starting 2026-09-30. Prior work (eDNA/conventional-fish feasibility
matching, now set aside) is in `FEASIBILITY_REPORT.md` — not repeated here.
Current focus: settling datasets for a long-term **cyanoHAB → fish** study.
No modeling yet.

---

## 2026-09-30 — NOAA CI product: corrected understanding

**Issue caught by user:** an earlier pass computed "% station-years with
detectable bloom" from raw per-pixel GeoTIFF rasters, treating any pixel
`1-250` as a valid observation and `255` as missing. This produced
implausibly high bloom-detection rates even in areas with almost no
satellite coverage (central/eastern Lake Erie).

**Resolution — read NOAA's own DataDocumentation.pdf (not a paraphrase)
(`raw/noaa_ci_samples/DataDocumentation.pdf`):**
- Pixel key is real: `0`=non-detection, `1-250`=valid (bloom intensity),
  `252`=land, `253-254`=cloud/invalid, `255`=no-data.
- **But empirically, in the per-pixel composite rasters, 0 and low values
  (1-41) are almost never output.** Direct check of one OLCI Erie composite
  (2023-07-10 to 07-19): of ~880k pixels, 65% land, 34% value-255, and of
  the remaining ~0.7% "valid" pixels, 99.27% were already above the bloom
  threshold (42) and only 1 single pixel had a low value. Water with no
  bloom signal appears to get folded into `255` alongside genuine
  cloud/sensor gaps in this product — so naively treating "not 255" as
  "valid, unbiased observation" overstates bloom prevalence.
- NOAA also ships **pre-computed, gap-filled basin-level CSV time series**
  (`intensity-extent-timeseries-csvs/`) for exactly 6 named regions:
  **Western Lake Erie, Lake Erie Central Basin, Sandusky Bay** (3 files
  each: CIsum + BloomArea), **Saginaw Bay** (Huron), **Green Bay + Lake
  Winnebago** (Michigan). These fuse MERIS/OLCI/CyanNet into one continuous
  2000-2024 series per region — this is the authoritative product to use,
  not raw-raster point extraction.
- **Same ambiguity persists even in the authoritative CSVs, per NOAA's own
  documentation**: *"Empty cells (NaNs)... represent no valid satellite
  observation... or all pixels being under the bloom detection threshold."*
  NOAA does not distinguish "no data" from "confirmed no bloom" anywhere in
  this product. This is a permanent limitation to design around, not a bug
  to fix.
- Spatial coverage confirmed authoritative: **Lake Erie (whole lake, 3
  sub-basins), Saginaw Bay (Huron), Green Bay/Winnebago (Michigan) only.
  No Ontario or Superior product exists at all** (not gated — genuinely not
  produced).
- Threshold definition (NOAA's own): bloom = DN > 42, equivalent to
  >20,000 cells/L; CI unit ≈ 10^8 *Microcystis* cells/mL.

**Practical implication:** prior point-extraction results
(`processed/ci_station_year.csv`, `ci_lake_subbasin_summary.csv`) are
superseded — not deleted, but should not be used for bloom-detection-rate
claims. Re-approaching via the basin-level CSVs (below).

---

## Part A: best standardized station-level fish survey per region

*(western Lake Erie confirmed now; Saginaw Bay / Green Bay flagged as an
open gap — see note)*

| Region | Survey | Years | Event N | Unique stations | Typical annual station N | Gear | Quantitative fields | Age/size/YOY? | Exact date? | Exact coords? |
|---|---|---|---|---|---|---|---|---|---|---|
| **Western Lake Erie** | **Lake Erie Fish Community Data** (USGS, DOI 10.5066/P14H3UIY) — the standardized recurring bottom-trawl index survey, isolated from the previously pooled 4,921-event western-basin collection (which mixed this with Maumee, larval tows, and hydroacoustic data) | 2013-2025 | 905 | ~41 fixed stations | ~35-41/yr (June + Sept passes) | Bottom trawl | count, density (N/ha), biomass (kg/ha) | No | Yes | Yes |
| Saginaw Bay | **No public station-level data exists.** MI DNR runs a real, recurring, bay-specific annual survey (~24 trawl tows + 16 gillnet lifts/yr at 4 fixed index grids since 1971, with CPUE/age/size/YOY) — but it is published only as narrative PDF reports (e.g. FR045.pdf), never as a downloadable per-event file. Exhaustively checked ScienceBase, data.gov, Michigan's ArcGIS open-data portal — nothing. | — | — | — | — | — | — | — | — | — |
| Green Bay | **No public station-level data exists.** Same situation: WI DNR runs a real ~78-site annual trawl survey since the late 1970s (yellow perch YOY density + other species) — PDF reports only (WDNR Lake Michigan Management Reports), no raw file anywhere public, including WDNR's ArcGIS portal and fisheries database endpoint (unreachable as a public download). | — | — | — | — | — | — | — | — | — |

**The only bay-specific public dataset found for either bay:** USGS "Fisheries-dependent data for Cisco in Green Bay and Saginaw Bay, 1929-1970" (DOI 10.5066/P9BAZSHV) — commercial catch/effort by *statistical district* (not station), Cisco only, monthly resolution, **no coordinates, ends in 1970** (60+ years before the CI satellite record starts). Not usable for this study. Downloaded to `raw/bay_specific_fish_surveys/` for completeness but not a candidate.

**Conclusion — Part A is now closed with a real answer, not a gap to keep chasing:** Saginaw Bay and Green Bay have no publicly downloadable station-level fish data covering any part of 2000-2024. The programs that would match exist and are exactly right conceptually — they're just locked in PDF-only state agency reports, which falls outside "public, downloadable" per this project's rules (no contacting investigators/agencies). Unless the user wants to manually extract numbers from PDF tables (a very different, much lower-throughput effort) or pursue direct agency contact, **these two regions cannot support Part C/D quantitative overlap analysis.**

---

## Part B: NOAA CI product verification (2000-2024)

Downloaded all 12 basin-level CSVs to `raw/noaa_ci_basin_timeseries/`
(GLErie: Western Lake Erie, Central Basin, Sandusky Bay; GLHuron: Saginaw
Bay; GLMichigan: Green Bay, Lake Winnebago — CIsum + BloomArea each). These
supersede the earlier raw-raster point-extraction approach entirely for
basin-level work.

**The `<Region>_fused` column is the one to use** — cross-sensor gap-filled,
2000-2024 continuous. Measured completeness (`% of 10-day periods DOY
151-310 with a non-null fused value`, all years 2000-2024):

| Region | Years | % complete (fused) | Composites/yr (expected ~16) | Median CIsum (where present) | Max CIsum |
|---|---|---|---|---|---|
| Western Lake Erie | 2000-2024 | 98.9% | 13-15 | 0.62 | 53.92 |
| Lake Erie Central Basin | 2000-2024 | 98.9% | 12-15 | 0.18 | 68.70 |
| Sandusky Bay | 2000-2024 | 98.9% | 12-15 | 1.40 | 2.83 |
| Saginaw Bay (Huron) | 2000-2024 | 99.7% | 14-15 | 2.23 | 13.20 |
| Green Bay (Michigan) | 2000-2024 | 99.2% | 13-15 | 1.02 | 5.96 |
| Lake Winnebago (Michigan) | 2000-2024 | — | — | — | not a Great Lake; inland lake bundled in this accession |
| **Lake Ontario** | — | — | — | — | **No product exists at all** |
| **Lake Superior** | — | — | — | — | **No product exists at all** |

This is a dramatically better completeness picture than the raw-raster
point-extraction gave (which only hit real fish-station coordinates
sparsely). **All 5 relevant regions have near-complete 25-year coverage at
the basin level.** Note units: `CIsum` here is NOAA's basin-summed
accumulated CI (their own dimensionless accumulation metric, threshold-gated
at DN>42 per pixel before summing) — not directly comparable to a raw
per-pixel DN value (0-250 scale). Don't mix the two scales in Part C/D.

**CI=0 vs no-data encoding, final answer:** real distinction exists in the
pixel key (0/1-250/255) but is empirically almost unused per-pixel; at the
basin-CSV level NOAA's own docs confirm NaN conflates "no observation" with
"all pixels below threshold" — this is a permanent, documented product
limitation, not something to work around. For Part C, "adequate CI
coverage" should be defined against **expected vs. valid composite count**
(this table gives the baseline: ~13-15 of ~16 expected per season, so >80%
complete is a reasonable default bar), not against a made-up detection rate.

---

## Part C: overlap feasibility — NOT YET DONE (next session)

**Only Western Lake Erie can go through Part C.** Saginaw Bay and Green Bay
are now closed out (Part A: no public station-level fish data exists for
either — not a research gap, a confirmed dead end under this project's
public-data-only rule). CI side is fully ready (Part B basin-CSVs
downloaded, completeness known). Western Erie fish survey already isolated
(905 events, 2013-2025, DOI P14H3UIY) — ready to overlap against the
Western Lake Erie CI fused time series whenever picked back up.

## Part D: recommendation table — NOT YET DONE

Depends on C.

---

## 2026-09-30 (cont'd) — NOAA CI raster archive: format, coverage, buffer test

User flagged the basin-level CSVs (used for Part B) are too spatially coarse
for station-level fish work. Re-confirmed the raster side (already
downloaded last session, `raw/noaa_ci/erie/{modis,olci}/`, 449 files) rather
than re-researching from scratch.

**Archive contents (NCEI accession 0312614, confirmed via DataDocumentation.pdf):**
- 3 raster products, all single-band uint8 GeoTIFF: MERIS (2002-2012,
  1km, Albers Conic Equal Area, whole-Great-Lakes grid "GL1"), MODIS-CyanNet
  (2000-2018 gap-filler, 1km, same Albers grid, organized per-lake
  directories Erie/Huron/Michigan), OLCI (2016-2024, 300m, UTM
  16N/17N, per-lake directories GLErie300m/GLHuron300m/GLMichigan300m —
  **no GLOntario/GLSuperior directories exist**).
- 10-day maximum composites. **Important correction to last session's
  assumption:** the raster archive is NOT limited to the June-Nov bloom
  season — it contains year-round composites (confirmed: 29 files for Erie
  2023, including January-May). The DOY 151-310 window only applies to the
  basin-CSV accumulation metric. Off-season composites are structurally
  ~100% nodata (ice/no bloom season) and must be filtered out manually by
  filename date for any bloom-relevant analysis — didn't corrupt earlier
  results (nodata just doesn't contribute) but wastes processing if not filtered.
- Whole accession: 0.143GB, 6,401 files, 21 folders (all lakes combined).
  Erie alone (both products, full year): 449 files as already downloaded.
- **Rasters are NOT pre-fused/harmonized across sensors** — only the
  basin-CSV `_fused` column does that gap-filling. For raster work, you
  pick one product per year yourself (this project used MODIS-CyanNet
  2006-2015, OLCI 2016-2024 — a reasonable, not-NOAA-prescribed choice).
- Coverage confirmed for Erie/Saginaw Bay/Green Bay; re-checked Ontario and
  Superior directly against the whole-Great-Lakes MERIS raster (3 mid-lake
  points each) — all nodata/land, consistent with no OLCI directory and the
  documentation's Purpose section naming only Erie/Sandusky/Saginaw/Green
  Bay/Winnebago as covered. Confidently no CI raster product for Ontario/Superior.

**Buffer extraction test** (10 random western-Erie WB-trawl stations, 2023,
OLCI, June-Nov composites only — `scripts/14_ci_buffer_extraction_test.py`,
`processed/ci_buffer_extraction_test.csv`):
- Point extraction: only 3.1% of station x composite pairs valid; only
  2/10 stations ever had a valid point value all season.
- **The gap is entirely explained by distance from the Maumee River
  mouth** (the real bloom hotspot) — tested directly: station 12.7km from
  the mouth had valid data in 10/13 composites (5km buffer); a station
  15.7km away had 9/13; every station >45km away had ≤3/13. This is a
  sharp, real spatial falloff, not noise.
- **5km buffers substantially rescue coverage** — all 10/10 stations got
  at least some valid season data with a 5km buffer, vs. 2/10 at the point
  level. 1km buffers helped much less than 5km.

**Bottom line — answering the question directly:**
**Yes, a station x 10-day CI exposure table can be produced cheaply from
the archived composites — no need to reconstruct CI from raw imagery.**
The data is small (a few hundred KB/file), the format is trivial to read
(rasterio), and bulk download for the full 25-year Erie record is
minutes of work (already proven last session: 449 files, ~5 min). BUT the
resulting table will be **sparse and station-position-dependent**: only
stations within roughly 20-30km of the Maumee mouth will have usable
point-level coverage most of the season; farther stations need a 5km+
buffer and will still have many missing 10-day periods. This is a real
optical-retrieval limitation of the product (blooms are only reliably
detectable in the turbid nearshore plume), not an engineering gap —
reconstructing CI from raw MERIS/MODIS/OLCI scenes would be a large,
specialized remote-sensing undertaking and would not fix this underlying
coverage limit, so it is not worth pursuing.

**Practical implication for Part C (next):** define "adequate CI coverage"
per station (not per basin) using a buffer (5km suggested, based on this
test) and expect coverage to vary sharply by station distance from the
Maumee mouth — this should probably be an explicit covariate/filter in
Part C, not just a pass/fail threshold.

---

## 2026-09-30 (cont'd) — Exposure variance decomposition: site effect vs. real year-to-year signal

Before any modeling: does CI exposure vary meaningfully within a site across
years, or is it basically a fixed site property (which would collapse
effective sample size to ~n_sites, since site FE would absorb it)?

**Method:** 6 real, fixed WB-trawl station IDs (`serial` field in the raw
catch data — genuinely the same physical station sampled repeatedly, not
rounded/deduplicated coordinates), spanning 9.8-89.4km from the Maumee
mouth, each with 12/12 years of data 2013-2024. Per station-year: cumulative
CI (5km buffer, sum of mean-in-buffer across all valid bloom-season
composites). `scripts/15_ci_exposure_variance_decomp.py`,
`processed/ci_exposure_site_year.csv`, `figures/ci_exposure_site_year.png`.

**Result: ICC (between-site / (between-site + within-site)) = 0.54.**
Roughly half the variance is a persistent site effect, half is real
year-to-year variation. Visually (see figure):
- **The two nearest stations (9.8km, 12.6km) and the farthest (89.4km)
  behave more like fixed site effects** — near stations are reliably near
  the top almost every year, the far one reliably near the bottom. These
  three are the most "location is the story" stations.
- **The three mid-distance stations (22.6km, 30.2km, 45.6km) show real,
  substantial rank-order crossing year to year** — e.g. 2019, 2021: no
  stable ordering among them. This is where genuine, non-redundant
  within-site exposure variation lives.
- **A shared year effect is visible across nearly all stations**
  (2022 shows a simultaneous spike at every station — consistent with a
  known bad lake-wide bloom year; 2021/2024 broadly lower). This is good
  news independent of the site question: a year-level covariate (e.g.
  spring loading, weather) could explain shared variance on top of site.
- Within-site coefficient of variation (std/mean of cumulative CI) ranges
  ~20-45% across the 6 stations — not trivial noise.

**Answer to the design question: the design is not dead, but it's not free
either.** n does not collapse to n≈6(or 12) sites — there's real signal to
model. But a naive pooled model would be wrong; this calls for **site
random intercept + year effect** (mixed model), not a flat regression on
CI. And **mid-distance stations (roughly 15-35km from the Maumee mouth)
carry the most independent information** — very-near and very-far stations
are largely redundant with "distance from mouth" alone and contribute
comparatively little beyond confirming the known spatial gradient. If
station selection is constrained (e.g. limited compute, want a clean
analysis subset), prioritize mid-distance stations.

**Caveat carried forward:** this used only 6 of the 82 real WB-trawl
stations — a good first look, not a full characterization. Extending to
all 82 (cheap, same pipeline, ~1 min per station) would firm up whether the
mid-distance-is-most-informative pattern holds generally or was an
artifact of these particular 6 picks.

---

## 2026-09-30 (cont'd) — Full 82-station classification + two-way variance decomposition

`scripts/16_full_exposure_decomposition.py`,
`processed/ci_exposure_all_stations.csv`,
`processed/station_bloom_classification.csv`,
`figures/station_bloom_classification_map.png`.

**(1) Inside/middle/outside classification.** First attempt (any bloom-season
composite in a station's 5km buffer ever exceeding CI>42, across 12 years)
**saturated — 82/82 stations classified "inside."** With a 5km buffer pooled
across a whole season, essentially every station catches at least one
elevated reading in at least one of 12 years (2022 in particular spread
blooms basin-wide — see the 6-station plot). Binary occurrence doesn't
discriminate. **Re-classified by intensity instead** — terciles of each
station's mean cumulative CI across its 12 years:

- **Inside (n=28):** mean dist-from-mouth 29.4km
- **Middle (n=27):** mean dist-from-mouth 52.4km
- **Outside (n=27):** mean dist-from-mouth 60.5km

Roughly even three-way split, correlated with distance from the Maumee
mouth as expected, but **not perfectly deterministic by distance** — the
map shows real intermixing (e.g. an "outside" station sitting directly next
to "inside" ones at the same longitude), consistent with the earlier
finding that location isn't the whole story.

**(2) Two-way crossed random-effects decomposition**
(`cumulative_CI ~ (1|station) + (1|year)`, statsmodels MixedLM, REML, all
82 stations x 12 years = 984 station-years):

| Component | Share (cumulative CI scale) | Share (n_bloom_composites scale) |
|---|---|---|
| Station | 63.6% | 53.0% |
| Year | 17.8% | 19.6% |
| **Residual** | **18.6%** | **27.4%** |

Residual SD on the literal bloom-days scale: **1.87 bloom-positive 10-day
composites ≈ ~19 days**, against a mean bloom-season exposure of ~7.5
composites (~75 days) per station-year.

**Verdict, using the user's own stated bar: design is alive.** Residual
share is 18.6-27.4% depending on response — comfortably at or above the
15-20% threshold specified, on both metrics tested, not "a few percent."
And the residual SD (~19 days) is a substantial fraction (~25%) of the
total bloom season length — a real, usable, ecologically meaningful
exposure difference, not statistical noise. Station (53-64%) is still the
single largest component — confirms geography matters most, as expected —
but year and residual together are 36-47% of variance, which is where a
real environment→fish effect would have to live and be estimable.

**Caveat:** this decomposition used only the intercept (no fixed effects);
residual here = station-year interaction + true noise, not yet separated
from each other. That split isn't needed to answer "is the design alive"
but would matter once actual modeling starts.

---

## 2026-09-30 (cont'd) — Sampling balance check (fish-survey side, not CI)

User asked directly: were the 82 stations sampled evenly across years and
against each other, or is this secretly 2 stations carrying most of the
weight? Checked the real WB-trawl visit records (not CI).
`scripts/17_sampling_balance_check.py`,
`figures/sampling_balance_heatmap.png`,
`figures/sampling_balance_per_station.png`,
`figures/sampling_balance_per_year.png`.

**Per station: well balanced.** No within-year replication anywhere (every
sampled station-year = exactly 1 visit). Total visits per station across
2013-2025 range **9-13 (median 11)** — a tight spread, not a
few-stations-dominate situation. Balanced within each bloom zone too
(inside/middle/outside all show min≈9-10, median≈10-11, max=13).

**Per year: NOT balanced — real gaps.** Most years sampled all 82 stations
(2013-2016, 2019, 2022, 2023, 2025), but:
- **2020: only 26/82 stations (32%)** — almost certainly COVID-related
- 2018: 41/82 (50%)
- 2024: 44/82 (54%)
- 2021: 67/82 (82%)
- 2017: 77/82 (94%)

The heatmap shows these gaps are scattered across stations/zones, not
concentrated in one zone or one part of the lake — reassuring for the
zone comparison, but it does mean the **year variance component from the
crossed decomposition is noisier for 2018/2020/2024 specifically** (fewer
stations contributing to those years' estimates). Worth keeping in mind if
those years turn out to be influential in any later modeling — 2020 in
particular is a thin, likely-anomalous year on the fish-sampling side
independent of anything bloom-related.

---

## 2026-09-30 (cont'd) — Modeling dataset built; sdmTMB blocked on broken Xcode CLT

Moving from diagnostics into actual model fitting: sdmTMB (R) for yellow
perch, walleye, white perch, emerald shiner, with bloom-days exposure
(current season + lag-1), station + year effects, surface temperature, and
an effort offset.

**Dataset built and complete** — `scripts/18_build_sdmtmb_dataset.py` →
`processed/sdmtmb_input.csv`. 911 WB-trawl events (2013-2025) →
**637 complete station-years (2014-2024, all 82 stations)** with: response
counts for all 4 species (`'ALL'` life-stage total, not YOY — the catch
table does carry a YOY/Age_1/Age_2+/YAO breakdown per species if that's
wanted later), `area_m2` (effort offset, log this in the model), near-surface
`temp_mean` from the paired water-quality cast (97.1% match rate),
`bloom_days_current` and `bloom_days_lag1` (= n_bloom_composites x 10, kept
as two separate terms rather than summed, so each lag gets its own
coefficient), and explicit `adequate_current`/`adequate_lag1` flags
(>=3 valid CI composites that station-year — same bar used in Part C) so
thin-coverage years are filterable rather than silently miscoded as
"no bloom." Species prevalence: yellow perch/walleye/white perch present
in ~90-95% of events; emerald shiner rarer (37%, 339/911) — may need a
delta/Tweedie or hurdle response family.

**Blocked: sdmTMB cannot install.** Root cause: macOS Xcode Command Line
Tools are registered (`xcode-select -p` returns a path) but broken — the
`xcrun` binary itself is missing. This fails ALL R source compilation, not
just sdmTMB — confirmed via the install log: TMB failed (via its RcppEigen
dependency), fmesher failed (via sf/splancs), and a dozen unrelated
packages failed with the identical `xcrun: error: invalid active developer
path` message. This needs a user-side fix (sudo + Apple's GUI installer),
which I can't do from this session. User is fixing it themselves; picking
this up once confirmed working — install script is staged at
`/tmp/install_sdmtmb.R`, log at `logs/sdmtmb_install.log`.

**Next step once R is fixed:** re-run the install, then write and fit the
sdmTMB formula, roughly:
`count ~ s(bloom_days_current) + s(bloom_days_lag1) + surface_temp + offset(log(area_m2))`
with `spatial = "on"`, a mesh over the 82 station coordinates, and
`time = "year"` for the spatiotemporal/year structure — exact family choice
(NB2 vs Tweedie vs delta-gamma) and whether station enters as a pure
spatial random field vs. an additional discrete random intercept still to
be decided per-species given the prevalence differences noted above.

---

## 2026-09-30 (cont'd) — Environment fixed, sdmTMB fit on all 4 species

**Environment saga (for future reference if this ever needs rebuilding):**
chain of blockers, each fixed in turn:
1. Xcode CLT registered but `xcrun` binary missing → user ran
   `sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install`.
2. `TMB`/`RcppEigen` failed to *link* — missing `gfortran` entirely (no
   compiler) → installed via `brew install gcc` (Homebrew, x86_64/Rosetta
   side at `/usr/local`, matching this R's x86_64 build — confirmed R 4.1.2
   binary is x86_64 running under Rosetta on this arm64 Mac).
3. `brew install gdal` (for `sf`, a hard dependency of `fmesher`) kept
   aborting during its cleanup phase on a permission error against
   `/usr/local/lib/docker` — an orphaned root-owned symlink to a
   long-deleted Docker.app. Fixed: user ran
   `sudo chown -R $(whoami):admin /usr/local/lib/docker`.
4. GDAL's default Homebrew formula then demanded a **full Xcode.app**
   install (multi-GB, for optional Java/grpc bindings never needed) —
   abandoned this path entirely. **Better fix: `install.packages("sf", type
   = "binary")`** — CRAN ships a macOS binary for R 4.1 with GEOS/GDAL/PROJ
   statically bundled, no system GDAL needed at all. Worked immediately.
5. `TMB`/`RcppEigen` *still* failed to link even with gfortran installed —
   R's `Makeconf` hardcodes `FLIBS` to a legacy fixed path
   (`/usr/local/gfortran/lib/...`) that doesn't match where Homebrew
   actually puts gfortran. Fixed with one symlink (user, sudo required
   since `/usr/local` top level is root-owned):
   `sudo mkdir -p /usr/local/gfortran && sudo ln -s /usr/local/Cellar/gcc/16.2.0/lib/gcc/current /usr/local/gfortran/lib`
6. `fmesher` has no CRAN binary for R 4.1 (too old) → installed `type =
   "source"`, worked fine once (2) and (5) were fixed.
7. `sdmTMB` itself then installed and loaded cleanly
   (`sdmTMB 1.1.0`, `fmesher 0.8.0`, `TMB 1.9.25`). A handful of
   Suggests-only packages failed (DHARMa, glmmTMB, lme4, qgam, plotly,
   RTMB) — all due to needing newer Matrix/mgcv than this R version
   supports. None block core `sdmTMB()` fitting; DHARMa specifically would
   have been nice for residual diagnostics and isn't available — noted as
   a gap, not a blocker.

**Model fit** — `scripts/19_fit_sdmtmb.R`, `scripts/20_summarize_sdmtmb_fits.R`.
All 4 species (yellow perch, walleye, white perch, emerald shiner), on the
637-row complete/adequate-coverage dataset, 2014-2024:

`count ~ 1 + bloom_days_current_scaled + bloom_days_lag1_scaled + surface_temp_scaled + (1 | year_f)`,
`family = nbinom2()`, `spatial = "on"` (persistent spatial field = station
effect), `offset = log(area_m2)` (effort). Mesh: 40 knots, kmeans, over the
82 UTM17N station coordinates (projected in R via `sf`, EPSG:32617 — same
CRS used for the OLCI CI rasters throughout this project).

**All 4 models converged cleanly** — `sanity()` returns `all_ok: TRUE` for
every one (positive-definite Hessian, no extreme eigenvalues, no large
gradients, no NA/huge SEs, no degenerate sigma or range parameters).
Full coefficient table: `processed/sdmtmb_coefficients.csv`. Forest plot:
`figures/sdmtmb_coefficient_forest.png`.

**Results (standardized coefficients, log-count scale, 95% CI):**

| Species | bloom_current | bloom_lag1 | surface_temp | Mat.rn range (km) | year RE SD |
|---|---|---|---|---|---|
| Yellow perch | -0.04 [-0.24, 0.15] | +0.09 [-0.09, 0.27] | -0.02 [-0.17, 0.13] | 64.0 | 0.83 |
| Walleye | +0.00 [-0.14, 0.14] | +0.05 [-0.09, 0.19] | **+0.16 [0.04, 0.28]** | 20.5 | 0.50 |
| White perch | -0.12 [-0.32, 0.08] | +0.17 [-0.02, 0.37] | **+0.38 [0.20, 0.56]** | 23.1 | 0.53 |
| Emerald shiner | +0.29 [-0.22, 0.80] | -0.07 [-0.55, 0.41] | +0.42 [-0.06, 0.91] | 11.6 | 1.62 (much larger — volatile year-to-year) |

**Honest headline: bloom-days exposure (current or lag-1) is not
significant for any of the 4 species in this baseline model** — every CI
comfortably spans zero. **Temperature is the real, consistent signal** —
significant and positive for walleye and white perch, suggestive (CI just
touches zero) for emerald shiner, null for yellow perch. White perch's
lag-1 bloom term is the closest thing to a bloom signal in this run
(CI lower bound -0.02, right at the edge) but doesn't clear significance.

This is a real, usable negative/null result for the bloom covariate as
specified, not a failure of the pipeline — every diagnostic says the models
themselves are well-behaved; spatial ranges are sensible (emerald shiner's
11.6km tight range vs. yellow perch's 64km near-basin-wide range tracks
known schooling-baitfish-vs-generalist ecology). Possible next steps if
pursuing the bloom question further: non-linear exposure-response (the
current spec is linear-on-log-count; a bloom threshold/saturation effect
could be masked), finer bloom-day definitions (intensity-weighted rather
than composite-count-threshold), or more station-years once pilot-era data
becomes legitimately available.

---

## 2026-10-01 — Robustness batch: effect sizes, temperature confounding, intensity-weighted exposure, YOY, sampling-design facts

Keeping the baseline model above as the reference null finding. This batch
tests whether it holds up. `scripts/21_percent_change_and_robustness.R`,
`scripts/22_build_yoy_dataset.py`, `scripts/23_pct_change_plot.R`.

**(4a) Are all fish samples the same time of year? No within-year repeat
visits.** Checked directly: the 82 stations split into two **permanently
fixed** groups — 41 always sampled in June, 41 always sampled in September,
every year, never both. Month is fully confounded with station identity.
**No June→September paired comparison is possible** with this dataset, as
expected. This also means any seasonal effect is already fully absorbed
into the model's station-level spatial random field — not a source of
hidden bias, just not separable from "station."

**(4b) YOY (age-0/recruitment) data: available, used.** All 4 species have
a YOY life-stage row at every event (911/911). Built
`processed/sdmtmb_input_yoy.csv`, refit the baseline model on YOY counts.

**(1) Percent change in catch per +19 bloom-days (one residual SD),
`figures/sdmtmb_pct_change_forest.png`, `processed/sdmtmb_pct_change_per_19days.csv`:**

| Species | Current season | Lag-1 year |
|---|---|---|
| Yellow perch | -2.5% [-12.6%, +8.7%] | +5.5% [-4.8%, +17.1%] |
| Walleye | +0.1% [-7.5%, +8.3%] | +2.7% [-5.3%, +11.4%] |
| White perch | -6.5% [-16.7%, +4.9%] | +10.3% [-1.4%, +23.5%] |
| Emerald shiner | +17.8% [-11.8%, **+57.2%**] | -3.9% [**-27.2%**, +26.8%] |

**Applying the user's own calibration rule:** yellow perch and walleye are
**defensible "no large effect"** results — both CIs sit entirely within
±~17%, comfortably inside the ±20-30% band. White perch is borderline-clean
(current term fully inside; lag-1 upper bound at +23.5%, just inside).
**Emerald shiner is NOT a clean null — confirmed the user's own prediction.**
Both CIs blow through the ±30% band (up to +57% current, -27% to +27%
lag-1) — the data genuinely cannot rule out a large effect either
direction for this species. Separately, not a modeling problem: emerald
shiner's low prevalence (37% of events) is almost certainly why.

**(2) Does temperature mask a bloom effect? No — bloom coefficients are
essentially unchanged with temperature removed from the model.** Direct
correlations are weak-to-modest: `cor(bloom_days_current, temp) = 0.268`,
`cor(bloom_days_lag1, temp) = 0.111`, `cor(cum_CI_current, temp) = 0.203`
— not enough collinearity to meaningfully confound. Re-fit without
`temp_s`: yellow perch and walleye coefficients barely move (e.g. yellow
perch bloom_current: -0.0445 → -0.0437). White perch's current-season term
shifts somewhat (-0.118 → -0.069, roughly halved) suggesting a small
amount of shared variance, but it was non-significant either way. **The
null bloom result is robust to temperature inclusion** — not an artifact
of temperature soaking up the signal. Full table:
`processed/sdmtmb_notemp_coefficients.csv`.

**(3) Intensity-weighted continuous exposure (`cumulative_CI`, not the
composite-count threshold) — mostly confirms the null, but surfaces one
real exception.** Refit with `cumCI_current_s` + `cumCI_lag1_s` in place of
`bloom_days_*`. Yellow perch, walleye, emerald shiner: still null (CIs
span zero) on both terms. **White perch's lag-1 term becomes significant:
+0.278 [0.048, 0.509]** — the one place in this whole batch where exposure
definition matters. A previous year's bloom *intensity* (not just
day-count) predicts more white perch the following year. Plausible
mechanisms (not tested): bloom-associated turbidity reducing predation on
juveniles, or nutrient/prey-base effects carrying into the next season —
speculative, flagging for a literature check before reading into it
further. Full table: `processed/sdmtmb_intensity_coefficients.csv`.

**(4c) YOY/recruitment models — temperature effects are large and highly
significant for all 4 species** (yellow perch +1.24 [0.84,1.64], walleye
+0.97 [0.67,1.26], white perch +1.44 [0.94,1.94], emerald shiner +1.23
[0.27,2.18] — all on the standardized-temp log-count scale, 3-8x the size
of the adult-model temperature effects). This is expected, known biology
(warm-year strong year-classes in these species) and a good sign the model
specification is sound. **Bloom effects on YOY are still mostly null**,
with one near-miss: **yellow perch current-season bloom is borderline
negative, -0.330 [-0.671, +0.011]** — upper CI bound sits almost exactly
at zero. The only current-season (not lagged) bloom effect across this
entire project that comes close to significance, and it's on the
recruitment-stage response where a real effect would most plausibly show
up first. Not significant, but worth a note for anyone revisiting this.
Full table: `processed/sdmtmb_yoy_coefficients.csv`. All 4 YOY models
passed `sanity(): all_ok = TRUE`.

**Bottom line for this batch:** the baseline null finding (items 1-3)
holds up well under scrutiny — it's not a temperature-confounding
artifact, and tightening the exposure metric mostly doesn't change it.
Two specific threads worth remembering if this project continues: white
perch's intensity-weighted lag-1 signal, and yellow perch's borderline YOY
current-season effect.

**Deferred to next session (user's own call — list was long):**
(5) smooth/non-linear bloom-days term (test for threshold/saturation
effects a linear term would miss), (6) Hmsc joint community model pooling
power across species against traits — bigger lift, needs a new R package
install + a trait table that doesn't exist yet.

---

## 2026-10-01 (cont'd) — Items 5 & 6

**(5) Smooth bloom-days term** — `scripts/24_smooth_bloom_term.R`.
`y ~ s(bloom_days_current, k=4) + s(bloom_days_lag1, k=4) + temp_s + (1|year_f)`,
all 4 species. **Clean, confirmatory null: the smoothing-wiggle variance
collapsed to exactly 0 for every species on both terms** — the penalized
smooth found no curvature beyond a straight line and degenerated back to
the linear fit (coefficients match the linear-model results almost
exactly, e.g. yellow perch bloom_current: -0.0445 linear vs -0.04 smooth).
`sanity()` flags `ln_smooth_sigma` SE as unreliable for all 4 — expected
and benign: it's a boundary-estimate artifact of a variance parameter
sitting at 0, not a problem with the effect estimates themselves. **No
evidence of a threshold/saturation bloom effect for any species** —
reinforces, doesn't complicate, the linear-model null.

**(6) Hmsc joint community model** — `scripts/25_fit_hmsc.R`,
`scripts/26_hmsc_plot.R`. Installed clean (binary, `sp`-based, no
GDAL/compile pain unlike sdmTMB). Scope, stated plainly: **presence/absence
(probit), not counts** (for fit speed/robustness on a first pass), and
**non-spatial** station+year random levels (no spatial mesh, unlike the
sdmTMB fits) — both are simplifications, not full parity with the
single-species models.

- **Community:** 16 species with >=10% prevalence in the 637-row complete
  dataset (Alewife dropped out at this stricter N). Trait table
  (`processed/hmsc_traits.csv`) is my own categorization from general
  fisheries-ecology knowledge for these well-studied species (feeding
  guild: benthivore/invertivore/piscivore/planktivore; native vs. invasive;
  habitat) — not pulled from a cited database, flagging that honestly.
- **Fit:** 2 chains, 1000 samples, 500 transient, thin 2, ~2.9 min.
  Converged well — Gamma (trait-interaction) PSRF all ~1.00-1.02; Beta
  (species-level) PSRF median 1.03, max 1.43 (a few parameters less
  precisely estimated, min ESS 141 vs median 839) — good enough for an
  exploratory read, not publication-grade.

- **Species-level bloom effects** (`processed/hmsc_species_beta.csv`,
  `figures/hmsc_species_effects.png`) — real, credible (posterior support
  >=95%) signals exist, concentrated in **benthivores**: Freshwater Drum
  (current +0.25, support 0.99; lag1 +0.21, support 0.98), Channel Catfish
  (current +0.19, support 0.999; lag1 +0.24, support 1.00), Quillback
  (current +0.14, support 0.97; lag1 +0.25, support 1.00) all show
  strong, confident positive associations with bloom-days on both terms.
  The one strong *negative* signal: **Rainbow Smelt, lag-1, support
  0.0095** (99.05% posterior probability the effect is negative) — the
  single most confident directional finding in this whole project. Notably,
  **Walleye's bloom_current effect here (+0.23, support 0.94) is much
  closer to credible than in the single-species sdmTMB count model (where
  it was flat null, 0.00)** — worth remembering that presence/absence
  pooled across species and the single-species count model are answering
  related-but-different questions, not a contradiction.

- **Trait-environment interactions (Gamma)** — `processed/hmsc_gamma_trait_env.csv`
  — **the formal test does NOT find credible evidence that feeding guild or
  native status systematically predicts bloom response.** Every
  guild/native-status x bloom_current_s or bloom_lag1_s term has support
  in the 0.29-0.74 range — nowhere near the 0.95/0.05 bar. Closest is
  native_status on both bloom terms (support ~0.70-0.74, native trending
  slightly more positive) but not credible.

**Honest synthesis of (6):** individual species show real, confident
responses to bloom exposure — the pattern visually clusters by guild in
the figure (3 of 4 strongest benthivore responses positive; the strongest
negative is the only clearly invasive-planktivore in the set) — but the
formal statistical test for a general trait-based rule doesn't clear the
credibility bar with only 16 species and 2-4 categories per trait. Reads
as: **real species-specific effects exist, but this project doesn't have
enough species/trait resolution yet to prove they organize by guild** —
a power problem, not necessarily evidence the guild hypothesis is wrong.

---

## 2026-10-01 — Hmsc refinement using Ludsin et al. 2001

User supplied the actual Ludsin, Kershner, Blocksom, Knight & Stein 2001
("Life After Death in Lake Erie," *Ecological Applications* 11(3):731-746)
PDF directly (prior web search only surfaced unreliable secondhand
fragments — correctly declined to guess from those). Extracted **Table 2**
by hand, cross-validated against the paper's own stated totals ("Of the 18
signal species examined, 10 were considered tolerant... six... intolerant...
two... moderate" — extraction matches exactly: 10T/6I/2M).

**Verified Ludsin Table 2 tolerance classifications:**
- **Tolerant (10):** Black Crappie, Bluegill, Brown Bullhead, Channel
  Catfish, Common Carp, Goldfish, Pumpkinseed, Quillback, White Crappie,
  White Sucker
- **Intolerant (6):** Burbot, Lake Whitefish, Rock Bass, "Minnows"
  (combined silver chub + sand shiner + ghost shiner + mimic shiner —
  Ludsin couldn't separate them in the field), Smallmouth Bass, Stonecat
- **Moderate (2):** Johnny Darter, Logperch

Critical caveat from Table 1's footnotes: **Ludsin's classification
deliberately excludes walleye, yellow perch, white perch, emerald shiner,
white bass, trout-perch, gizzard shad, rainbow smelt, alewife, spottail
shiner, and freshwater drum** — removed as common walleye-prey species (to
avoid predation confounding) or, for white perch/round goby, as
post-1969/post-study exotics. **None of the 4 original sdmTMB target
species carry a Ludsin label.**

**Species set** (≥5% prevalence, ≥3 years, ≥5 stations, 637-row dataset):
**17 species.** Of these, only 4 carry a direct Ludsin classification —
Channel Catfish, Common Carp, Quillback, White Sucker — **and all four are
Tolerant.** Zero Intolerant/Moderate species clear the bar (Smallmouth Bass
closest at 4.6%, just under 5%). **Flagged to user as a result in its own
right, not just an obstacle:** this is the same pattern Ludsin's own paper
documents — their west basin (same basin, same ODNR-ODW trawl program,
just a later era) was historically dominated by tolerant species, with
intolerant-species recovery concentrated in the *central* basin instead.
Modern data (2013-2025) shows the same skew holding 15-30 years later —
worth reporting as evidence the west basin's community composition has
remained structurally tolerant-dominated across half a century.

**User's resolution** (asked directly before proceeding): for the
Ludsin-restricted analysis only, admit Smallmouth Bass and Rock Bass
(Ludsin-Intolerant, real species already present, just below the main 5%
bar) — giving a real if thin 4-vs-2 contrast. Main 17-species set
unaffected.

**Trait table** — `processed/hmsc_traits_v2.csv`, every field sourced
per-row: Ludsin Table 2 directly for the 6 Ludsin species (tolerance +
thermal guild, high confidence); Becker 1983 *Fishes of Wisconsin* /
Trautman 1981 *The Fishes of Ohio* for feeding guild / habitat / visual
predator on all species and thermal guild on the 13 non-Ludsin species
(general fisheries-ecology knowledge, not page-verified — flagged
per-row where a call was a judgment ambiguity). Nice cross-check: Silver
Chub's invertivore classification is independently corroborated by
Ludsin's own Discussion section, which documents silver chub diet tracking
*Hexagenia* mayfly recovery in west-basin sediments. Silver Chub itself
kept `ambiguous` (not assigned Ludsin's pooled "Minnows" label) since
Ludsin never classified it individually.

**User's mid-batch strategic pivot**, prompted by the all-Tolerant finding
above: reorganize so (1) the full 17-species community model is PRIMARY —
report the distribution of species-specific bloom responses directly; (2)
Ludsin tolerance becomes a focused/exploratory historical hypothesis test
on the 6-species subset, explicitly not decisive; (3) broader traits
(feeding guild, habitat position, thermal guild) — assignable to nearly
the whole 17-species set — become the main formal community trait test
instead of Ludsin tolerance, since they're far better powered.

**Finalized base model (item 0), implemented exactly as specified:**
presence/absence (probit); `cumCI_current_s` + `cumCI_lag1_s` (standardized
**continuous** cumulative CI, not the composite-count bloom-days threshold
used in the first Hmsc pass); `temp_s`; **year as a fixed categorical
effect** (not random, unlike the first pass); effort (`log_area_s`) —
checked and kept, since swept area genuinely varies (CV=14.4%, range
4,616-12,167 m², 636 distinct values across 637 events); **station as a
real spatial random level** using actual UTM17N coordinates (not a plain
factor level like the first Hmsc pass) — `sData` argument, Hmsc's GP-based
spatial model. No phylogeny, no extra spatial field, no other covariates.

One technical snag: Hmsc's spatial random level requires unique
coordinates, but 9 station-serial pairs (e.g. 121/521, 108/508) share
*exactly* identical GPS coordinates (same physical site, evidently two
labeled sub-series). Fixed with a deterministic 2-meter jitter applied only
to exact duplicates (`scripts/27_fit_hmsc_v2.R`) — far below any
ecologically meaningful spatial scale.

**Two models fit**, both converged well (PSRF ~1.0 for both Beta and
Gamma; Model A max Beta PSRF 1.44 on one parameter, acceptable for
exploratory work; Model B cleaner, max 1.04):

### Model A (PRIMARY): 17-species, broad-trait Gamma, ~10 min fit

`processed/hmsc_fit_A_primary_17species.rds`,
`processed/hmsc_v2_speciesA_beta.csv`, `figures/hmsc_v2_modelA_species.png`.

**Species-level bloom effects** (credible = posterior support >=95% or
<=5%):

| Species | Current (mean, support) | Lag-1 (mean, support) | Guild |
|---|---|---|---|
| Freshwater Drum | **+0.38 (0.998)** | +0.03 (0.60) | benthivore |
| Walleye | +0.29 (0.948, just shy) | -0.08 (0.34) | piscivore |
| Channel Catfish | **+0.22 (0.999)** | **+0.16 (0.974)** | benthivore |
| Yellow Perch | +0.20 (0.912) | -0.09 (0.24) | invertivore |
| Trout-perch | **+0.18 (0.975)** | -0.09 (0.17) | invertivore |
| Emerald Shiner | **+0.15 (0.960)** | +0.05 (0.71) | planktivore |
| Quillback | +0.11 (0.891) | **+0.25 (0.994)** | benthivore |
| White Bass | -0.14 (0.061, near-credible neg.) | **+0.22 (0.995)** | piscivore |
| **Rainbow Smelt** | -0.12 (0.091) | **-0.22 (0.0065)** | planktivore |
| Alewife | -0.18 (0.132) | -0.21 (0.072, near-credible neg.) | planktivore |
| Common Carp | ~0 (null) | +0.15 (0.933, near) | benthivore |
| (White Sucker, Round Goby, Gizzard Shad, White Perch, Silver Chub, Spottail Shiner) | null on both | null on both | mixed |

**The Rainbow Smelt lag-1 negative finding replicates independently** —
support 0.0065 here (99.35% probability negative) vs 0.0095 in the first,
methodologically different Hmsc pass (non-spatial, composite-count
exposure, year-random). Two different model specs, same striking result —
genuinely robust now, not an artifact of one modeling choice.

**New in this pass:** White Bass's lag-1 effect (+0.22, support 0.995) is
strongly credible and wasn't flagged before — a piscivore, not a
benthivore, breaking any simple "benthivores good / planktivores bad"
story the first pass's figure suggested. The guild pattern is messier on
closer, better-powered inspection, not cleaner.

**Broad-trait Gamma (feeding guild x habitat x thermal guild) — still no
single credible trait-environment link** (`processed/hmsc_v2_gammaA_broadtraits.csv`):
every category's support sits in the 0.29-0.77 range, nowhere near 0.95/0.05.
Closest: thermal_guild=warm on lag-1 (support 0.773).

**But R2T$Beta (trait-explained variance in species' environmental
responses) tells a more nuanced story:** traits jointly explain **11.8%**
of cross-species variance in the current-season bloom response and **20.3%**
in the lag-1 response — real, non-trivial explanatory power even though no
single trait *category* clears the credible-interval bar individually.
Reads as: these 3 traits *do* capture something about why species differ
in lag-1 response, just not cleanly along any one of the category splits
tested.

**Variance partitioning context:** year is the dominant variance source for
most species (28-78%), consistent with the earlier sdmTMB finding of a
real shared year effect. Station (spatial) dominates for the more
patchily-distributed species (Gizzard Shad 95%, Trout-perch 77%, Round
Goby 75%). cumCI_current_s alone reaches 20-25% of variance for Freshwater
Drum and Channel Catfish specifically — a meaningfully large share for
those two.

**Model fit:** Tjur R2 (in-sample, presence/absence) ranges 0.04-0.75
across species — normal range for this kind of model, Gizzard Shad fits
best (0.75), Yellow Perch/Walleye weakest (~0.06-0.10, expected since
they're present in >90% of events with little variance left to explain).

### Model B (FOCUSED/EXPLORATORY historical test): 6 Ludsin species, ~7 min fit

`processed/hmsc_fit_B_ludsin_focused_6species.rds`,
`processed/hmsc_v2_speciesB_beta.csv`, `figures/hmsc_v2_modelB_ludsin.png`.
**Explicitly not treated as a decisive community-wide test** — thin sample
(4 tolerant vs 2 intolerant), by design.

| Species | Tolerance | Current | Lag-1 |
|---|---|---|---|
| Channel Catfish | tolerant | +0.215 (0.994) | +0.161 (0.969) |
| Quillback | tolerant | +0.133 (0.902) | **+0.253 (0.994)** |
| Common Carp | tolerant | ~0 (0.49) | +0.124 (0.864) |
| White Sucker | tolerant | +0.055 (0.76) | -0.023 (0.40) |
| **Smallmouth Bass** | **intolerant** | **-0.304 (0.050 — exactly credible negative)** | +0.126 (0.75) |
| Rock Bass | intolerant | ~0 (0.51) | -0.232 (0.089) |

**The key tolerance x bloom Gamma result** (`processed/hmsc_v2_gammaB_tolerance.csv`):
- Current season, tolerant vs intolerant: mean **+0.177**, support **0.691**
- Lag-1, tolerant vs intolerant: mean **+0.202**, support **0.721**

**Directionally consistent with Ludsin's own theory** (tolerant species
trend more positive under bloom exposure than intolerant, on both lags) —
**but not formally credible** (support ~0.69-0.72, well short of 0.95).
Individually, though, Smallmouth Bass's own current-season coefficient
*is* independently credible (support exactly 0.050) — a specific, real
data point in the predicted direction even though the aggregate
tolerance-group test isn't strong enough to call decisive with n=2
intolerant species.

**Headline synthesis for this round:** the primary 17-species result shows
real, credible, individually-strong species responses (strongest ever
found: Rainbow Smelt lag-1, Channel Catfish/Freshwater Drum/Quillback
current or lag-1) that replicate across two independent model
specifications — but neither broad ecological traits nor Ludsin's
historical eutrophication-tolerance classification *formally* explain the
pattern at a credible level, despite both showing suggestive directional
signal (R2T=20% for broad traits on lag-1; tolerant-trending-positive for
Ludsin groups). The western-basin community in 2014-2024 is
**heterogeneous in its bloom response, not uniformly resistant or
uniformly sensitive — and that heterogeneity doesn't yet resolve cleanly
along any single trait axis tested.**

**Not yet done:** Cramér's V among traits (item 3 — lower priority now
given the reprioritization). Item 7 sensitivity (external tolerance
sourcing for non-Ludsin species) not started.

# Lake Erie Fish x Hmsc x NOAA Cyanobacteria Index

Does cyanobacterial harmful algal bloom (HAB) exposure, measured from NOAA's
satellite Cyanobacteria Index (CI), show up in Lake Erie fish community
structure and focal-species catch? Scripts here cover the full pipeline from
raw CI/fish-survey data through spatiotemporal (sdmTMB) and joint
community (Hmsc) models.

Run in numeric order; each script's docstring/header states its purpose and
inputs. Raw data, processed intermediates, figures, and logs are not
committed (see `.gitignore`) — see `methods_and_results.md` for the full
narrative log of methods, decisions, and results at each stage.

## Pipeline

- `13_noaa_ci_extraction.py` — extract NOAA CI at every fish station x year (2006-2024)
- `15_ci_exposure_variance_decomp.py`, `16_full_exposure_decomposition.py`,
  `17_sampling_balance_check.py` — pre-modeling checks: is bloom exposure a
  station effect or a real year-by-station design; sampling balance
- `18_build_sdmtmb_dataset.py` — build the sdmTMB station-year analysis table
- `19_fit_sdmtmb.R`, `20_summarize_sdmtmb_fits.R` — baseline sdmTMB fits
  (4 focal species) and summary
- `21_percent_change_and_robustness.R` — percent-change effect sizes,
  no-temperature-confounding check, cumulative-CI intensity-weighted refit
- `22_build_yoy_dataset.py` — young-of-year/recruitment outcome dataset
- `23_pct_change_plot.R` — effect-size figure
- `24_smooth_bloom_term.R` — non-linear/smooth bloom-term robustness check
- `27_fit_hmsc_v2.R` — primary Hmsc joint species distribution models:
  Model A (17-species community, broad traits) and Model B (focused
  Ludsin et al. 2001 eutrophication-tolerance test, 6 species), real
  spatial random field over stations
- `28_extract_hmsc_v2_results.R`, `29_hmsc_v2_plots.R` — Hmsc posterior
  extraction and figures

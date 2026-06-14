# Changelog

## v0.8.1 — 2026-06-14

- Reworked the page model into 4 configurable graph pages and 4 data pages.
  Each graph page picks a type (off / load / any metric) and its own round
  or rectangular shape; each data page picks off / form / recovery / sleep /
  body / fuel / feel / status. Replaces the old fixed chart slots, the global
  round-charts toggle, and the per-page show/hide switches.

## v0.8.0 — 2026-06-14

- Interactive chart zoom: START opens a zoom control on the chart pages with
  bold +/- glyphs beside the UP/DOWN buttons. UP/+ zooms in (fewer days),
  DOWN/- zooms out (more days), 7–90 days in stops (7/14/21/30/42/60/90);
  touch taps the upper/lower half. The trend is always fetched at 90 days and
  the zoom slices it for display, so rescaling is instant and offline.
  Replaces the old fixed "Chart window" setting.
- Line charts interpolate with an adaptive Catmull-Rom spline, so narrow
  windows render a smooth curve through the daily points instead of an
  angular polygon; wide windows stay effectively straight at no cost.
- HRV charts draw each day's bar from the centre of the baseline (green) band
  to its value, reading as a deviation from the personal baseline.

## v0.7.0 — 2026-06-12

- Device support expanded from the Fenix 8 Pro to **59 round, glance-capable
  Garmin devices** (Fenix 7/8/E, Epix 2, Forerunner 165–970, Venu 2–4,
  vívoactive 5/6, MARQ 2, Descent G2/Mk3, Approach S50/S70, Instinct 3
  AMOLED, Enduro 3, D2), verified by a per-device compile matrix.
- Responsive layouts: all font sizes and offsets scale with screen size
  (calibrated to the original 454px design; fixes overflow on 260px MIP).
- Build tooling: `--export` (beta store package) / `--export-prod`
  (production package with its own app ID) / `--all` (per-device sideload
  .prgs) / `DEVICE=` and `APIKEY=` overrides.

## v0.6.x

- Glance: configurable display (fit+fat+form / fitness / fatigue / form-only
  chart), chart margin tightened, mini banded CTL/ATL chart.
- Zone palette tuned twice (clear blue fresh band, muted high-risk red).
- Per-page show/hide toggles, including the form page.
- HRV charts: personal baseline band (window mean ± 0.75 SD) with
  deviation-colored bars.
- Settings synced from the phone coerce String/Float values to Number.
- Two rounds of font size increases across all pages.

## v0.5.0

- Stat-tile redesign with auto-fitting vector fonts.
- Polar load chart (form-zone bands wrapped around the bezel) and radial
  ring charts; "Round charts" toggle.
- Configurable chart slots and ring chart; chart window 6w/3m/6m.

## v0.1–0.4

- Initial widget: glance, form/load/wellness pages, hourly background sync
  against the intervals.icu API with chunked trend fetches, store beta
  export, screenshots, MIT-licensed repo.

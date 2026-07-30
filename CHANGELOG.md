# Changelog

## v0.9.2 — 2026-07-30

- **The status page can always start OAuth linking**: press START there
  whenever the account isn't linked, and a "Press START to link OAuth" prompt
  now advertises it. Previously the only entry points were first-run setup, the
  migration nudge, and a reconnect error — so anyone who had snoozed the nudge
  was locked out of linking for 14 days. (Enable a Status data page in settings
  to reach it.)

## v0.9.1 — 2026-07-30 (beta)

- **Fixed: OAuth never completed on real watches.** Garmin Connect Mobile only
  captures the result when the consent page redirects to `http://localhost`
  (it watches for that navigation and never loads it), so our hosted redirect
  URL was silently ignored on hardware — the simulator was more permissive,
  which masked the bug. Both the authorize request and the token exchange now
  use `http://localhost`.
- **Fixed: "CONNECTING…" could latch forever.** The connecting state now times
  out after 3 minutes, so START always works again after an abandoned or failed
  login.
- OAuth registration moved to app start: per Garmin's docs, a login finished
  after the widget times out is cached and delivered on the next registration,
  so it now completes on next open instead of being lost.
- While linking, the app directs the user to open Garmin Connect on the phone
  (previously it showed only a bare "CONNECTING…").

## v0.9.0 — 2026-07-30 (beta)

- **Link your intervals.icu account from the watch (OAuth).** Press START when
  not connected: consent opens on your phone via Garmin Connect, scoped to
  wellness data only — no more copying API keys. A minimal Cloudflare Worker
  (`worker/`) performs the token exchange so the client secret never ships in
  the app.
- **API key entry is deprecated** and will be removed in v1.0. Existing key
  users keep working and see a relink nudge page at most every 14 days
  (START to connect, DOWN to snooze); the status page marks key auth as
  "legacy" in amber.
- 401/403 now surfaces as "Reconnect intervals.icu". Note intervals.icu answers
  bad OAuth client credentials with HTTP 404, so exchange failures report
  "Connect failed" rather than being mapped as API errors.
- Project site, privacy policy and OAuth redirect page under `docs/`
  (GitHub Pages).

## v0.8.3 — 2026-07-03

- Thicker fatigue (ATL) line: pen 4 in the load charts (matching the
  fitness line), pen 3 in the combined glance chart, pen 4 in the
  fatigue-only glance.

## v0.8.2 — 2026-07-03

- **Fixed: form zone coloring now matches intervals.icu** (#1, thanks
  @tinkeringtuck). Zones were computed as form-as-%-of-CTL but intervals.icu
  colors by absolute TSB points (+20 / +5 / −10 / −30), so e.g. form −18 at
  CTL 48 showed High Risk instead of Optimal. Absolute is now the default
  for the zone label/color and every chart band (load, polar load, glance).
- The "Form as % of fitness" setting now switches the zone scale along with
  the displayed value, for athletes using intervals.icu's percent option.
- Chart auto-range headroom follows the active zone scale, so the optimal
  and high-risk bands stay visible in absolute mode at low CTL.
- build.sh works on Windows Git Bash as well as macOS (#1, @tinkeringtuck).

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

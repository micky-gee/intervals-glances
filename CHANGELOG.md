# Changelog

## v0.11.12 — 2026-09-19

**Fitness, fatigue and form on your watch face.** The app publishes a
complication named "Intervals data" carrying all three numbers in one string -
`31/15/+16`, or `31/15/+52%` when "Form as %" is on. Add it to any watch face
that supports Connect IQ complications, or to Face It. It follows the app's own
rounding and form scale, so it can never disagree with the pages inside the
app, and the background sync refreshes it, so a face stays current between
opens. It costs **no extra API requests** - it only reads the cache the sync
already keeps.

One complication rather than one per metric: a watch's picker only ever offers
the first complication an app declares, so a single string carrying all three
is worth more than three values that cannot be chosen.

**Fenix 9 support** - all seven variants (43mm, 47mm/51mm, Pro 43/47/51mm, Pro
Solar 47/51mm), taking the app to 66 devices. The Pro Solar models are MIP at
260x260 and 280x280, the same geometry as the already-supported fenix 7 and 7X.

**Fixed a crash on watches without a graphics accelerator.** Opening the app on
a Forerunner 255 tripped the Connect IQ watchdog (`Code Executed Too Long`)
while drawing the polar load chart - the default first page - so the app
crashed on open. This affects the 18 MIP devices among the 66 supported: fenix
7/7S/7X and Pro variants, fenix 8 Solar, fenix 9 Pro Solar, Forerunner
255/255s/955 and Enduro 3, none of which have the GPU the AMOLED models use.
The chart code was unchanged since v0.8.3, so the crash had been present in
production since then.

The cause was two kinds of work that produced nothing on screen. The spline
renderer solved a Catmull-Rom cubic per segment even when the step count worked
out to one per span - and such a span evaluated at its endpoint is exactly the
next control point, so 178 cubics per frame were being solved to draw a plain
polyline. And the zone-band underlays were antialiased, which does nothing for a
solid fill built from overlapping strokes. Antialiasing is now kept for the data
curves only, the underlays follow a step budget instead of a fixed 241 spokes
(or one strip per pixel column on the rectangular chart), and the ring chart's
baseline band is one arc as thick as the band rather than one arc per radius
pixel. The chart now draws on a Forerunner 255 in 7-12 ms.

**A faster glance.** The glance stalled as it scrolled into view and again as it
took focus. Three causes: the form-zone bands behind its chart were antialiased,
which costs time on a vertical line and changes nothing; every data accessor
re-read and deserialised the whole cache from Storage, six times per draw, where
once per draw will do; and taking focus re-registered the wake and
activity-completed background events every time, though those persist on the
device until unregistered. Measured on the watch itself, since the simulator -
where Storage is memory and drawing is native - reproduced none of it.

**Text pages re-spaced, with bigger numbers.** Values on the tile pages are now
the largest the row can hold, 76px against 68px before on a 454px watch, and the
tiles run from just under the header to just above the page dots instead of
stopping short at both ends. Tile width follows the screen's actual shape: a row
near the top or bottom of a round display sits on a shorter chord than one
across the middle, so a single fixed width both wasted the middle and overhung
the ends. The middle row is now half again as wide as before. Long labels shrink
to fit instead of running past their tile, the status page pairs its rows so the
longest values land on the widest row, and on the form page the hero number and
the zone label below it no longer overlap.

Versions 0.11.0-0.11.11 were beta-only iterations of the above and never
reached production.

## v0.10.0 — 2026-08-02

Roughly a **10x cut in intervals.icu API usage** (~58 → ~5 requests per user per
day), lifting the ceiling the 8,000/day limit imposes from ~140 users to well over
a thousand. No change to what you see; syncs now land closer to when data actually
changes.

- **Delta sync.** Past wellness days are immutable, so a sync now fetches only
  yesterday and today — **one request** — and merges it into the cache, instead of
  re-downloading 90 days of history every time (four requests). The window widens
  automatically if the watch has been offline.
- **Event-driven instead of hourly polling.** Syncs are scheduled by the events
  that matter — waking (overnight HRV/sleep/resting HR) and finishing an activity
  (training load) — with a ~6 h safety net. Each event schedules the sync a little
  later (~45 min after wake, ~20 min after an activity) so the data has time to
  reach intervals.icu via Garmin Connect, and every delay is jittered per watch.
- **Progressive history**: 30 days on first load; the older 60 days are fetched
  once, only if you zoom past 30 days.
- **Backoff on authentication failures.** A revoked key or token used to retry
  every hour indefinitely; it now backs off (and can never block a newly linked
  account).
- Widget-open refresh threshold relaxed from 15 minutes to 2 hours.

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

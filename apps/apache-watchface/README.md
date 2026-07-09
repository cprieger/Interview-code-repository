# AH-64E Apache Watch Face

A Garmin Connect IQ watch face for the **fenix 7X Pro Sapphire Solar**, styled like an
AH-64E Apache cockpit MFD/HUD: big digital clock in the center, HUD corner brackets,
and gauge-style readouts around the edge.

Everything is drawn programmatically (no bitmap art besides the launcher icon) —
flat fills, no gradients, legible on the watch's MIP display.

**Heads up:** this was written without access to the Connect IQ SDK/simulator, so it
has not actually been compiled. The Monkey C is written carefully against the
official API docs, but you should expect a couple of small compiler-error fixes on
first build (see "Known risk areas" below) — normal for a first pass on a new SDK
project.

## What's on screen

| Position | Field |
|---|---|
| Center (largest) | Hours : Minutes, with smaller Seconds beside it (seconds hidden in Always-On mode) |
| Top left | Battery % with a fill-proportional battery icon |
| Top right | Heart rate, red heart icon |
| Bottom left | Step count, footprint icon |
| Bottom right | Next solar event (sunrise before sunrise, sunset after), yellow sun icon |
| Bottom center | Date, e.g. `WED 08/07` (format configurable in Garmin Connect app settings) |
| Very bottom | Temperature + weather icon (sunny/cloudy/rain/snow/storm) |

Day mode: white text, cyan HUD accents, yellow solar icon, red heart icon.
Always-On mode: monochrome, seconds hidden, weather icon simplified to sunny/cloudy,
heart rate and weather refresh less often.

## 1. Set up your local environment

You need three things: the **Connect IQ SDK**, an **editor with the Monkey C
extension**, and a **developer key** (required to sign anything you build, even for
local sideloading).

1. **Install the SDK Manager**
   Download it from the [Connect IQ SDK page](https://developer.garmin.com/connect-iq/sdk/)
   (Windows installer). Run it once — it installs the SDK Manager app.

2. **Install an SDK + the fenix 7X Pro device files**
   Open SDK Manager → install the latest Connect IQ SDK → in the "Devices" tab,
   make sure **fenix 7X Pro** is checked/installed. This is also where you can
   search the device list to confirm the exact internal device id (see step 4).

3. **Install VS Code + the Monkey C extension**
   Garmin's current official toolchain is the **Monkey C extension for VS Code**
   (the old Eclipse-based IDE is deprecated). Install
   [VS Code](https://code.visualstudio.com/), then install the "Monkey C" extension
   from the marketplace (publisher: Garmin).

4. **Point the extension at your SDK**
   Command palette → `Monkey C: Configure Current Project` (or it'll prompt you on
   first open) → select the SDK you installed in step 2.

5. **Generate a developer key** (one-time, reused for every project)
   Command palette → `Monkey C: Generate Developer Key`. Save it somewhere outside
   this repo (e.g. `~/.garmin/developer_key.der`) — **do not commit it**. Point the
   extension at it in its settings (`monkeyC.developerKeyPath`).

6. **Open this folder in VS Code**
   `apps/apache-watchface/` — the extension auto-detects `manifest.xml` and
   `monkey.jungle`.

7. **Verify the device id in `manifest.xml`**
   Garmin's device-id strings for the fenix 7 Pro line are inconsistent across
   SDK releases (the original 2023 "Sapphire Solar" Pro shipped as a solar-only,
   no-WiFi SKU). `manifest.xml` currently lists both `fenix7xpro` and
   `fenix7xpronowifi` as candidates. Run `Monkey C: Edit Project` and use its
   device picker to see which id(s) your installed SDK actually has for
   "fenix 7X Pro" / "fenix 7X Pro Sapphire Solar", and delete whichever entry
   doesn't exist (an id the SDK doesn't recognize will fail the build).

## 2. Build & run in the simulator

- Command palette → `Monkey C: Run` → pick **fenix7xpro** (or whichever id you
  kept) → this builds and launches the Connect IQ Simulator.
- In the simulator, use the **Sensors** menu to fake heart rate/step data, and
  the **location** picker so `Weather`/sunrise-sunset have something to compute
  from (both are `null`-safe in the code — they'll just show `--` until a
  location/weather source is available).
- Toggle Always-On mode from the simulator's watch-face menu to check the
  monochrome/seconds-hidden styling.

## 3. Sideload to your watch

1. Command palette → `Monkey C: Build for Device` → produces a `.prg` in `bin/`.
2. Connect the watch by USB — it mounts as a mass-storage drive.
3. Copy the `.prg` into `GARMIN/APPS/` on the watch.
4. Eject/disconnect. The watch face appears in your watch face list within a
   few seconds.

(Garmin Express can also push it, but the drag-and-drop above is simpler for
iterating during development.)

## 4. Publish to the Connect IQ Store

1. Register as a Connect IQ developer (free) at the
   [Connect IQ Developer Portal](https://apps.garmin.com/developer/).
2. Command palette → `Monkey C: Export Project` (or `Build for App Store`) to
   produce a signed `.iq` package using your developer key.
3. In the developer portal, create a new app listing, upload the `.iq`, and
   fill in the store metadata (name, description, screenshots — take these
   from the simulator).
4. Submit for review.

One thing worth knowing before you submit: **"AH-64E Apache" is real Boeing
branding/trademark.** This watch face doesn't use any Boeing artwork, name, or
insignia in the code or icon — it's just a HUD-style *aesthetic* (crosshair
reticle, corner brackets, angular readouts). Keep the store listing's name and
description generic ("military HUD watch face" rather than "AH-64E Apache
watch face") to stay clear of any trademark issue, especially since this is a
public store submission and not just a personal sideload.

## Files

| File | Purpose |
|---|---|
| `manifest.xml` | App id, target device(s), permissions (`Positioning`, for sunrise/sunset) |
| `monkey.jungle` | Build config (source/resource paths) |
| `source/ApacheWatchFaceApp.mc` | App entry point |
| `source/ApacheWatchFaceView.mc` | Main draw loop, field layout, sleep/wake handling |
| `source/DataCache.mc` | Throttled weather/heart-rate/solar-event refresh (see below) |
| `source/HudDraw.mc` | Vector icon drawing (battery, heart, footprints, sun, weather) + weather-condition-to-icon mapping |
| `source/ColorScheme.mc` | Day vs. Always-On color palette |
| `resources/` | Strings, the DD/MM vs MM/DD date-format setting, launcher icon |
| `tools/generate_launcher_icon.py` | Regenerates the placeholder launcher icon (needs `pip install Pillow`) |

## Battery optimizations, and how they're implemented

- **Weather refresh**: every 15 min while awake, every 45 min in Always-On
  (`DataCache.AWAKE_WEATHER_INTERVAL_SEC` / `SLEEP_WEATHER_INTERVAL_SEC`).
- **Heart rate refresh**: every 5s awake, every 60s in Always-On.
- **Solar event**: computed once per calendar day, cached.
- **Redraw only what changes**: there's deliberately no `onPartialUpdate()`
  override. Seconds are hidden in Always-On mode, so there's nothing that needs
  a per-second redraw while sleeping — without a partial-update handler, the
  system's default low-power behavior is to call `onUpdate()` once a minute,
  which already matches the brief.
- Battery % and step count are cheap local stat reads (no I/O), so those are
  just re-read on every draw rather than cached.

## Known risk areas (things to double check on first build)

I don't have the Connect IQ SDK installed in this environment, so none of this
was actually compiled or run in the simulator. The API calls are written
against Garmin's published docs, but flag these if the build errors out:

- **Device id** (`manifest.xml`) — see step 7 above, genuinely ambiguous from
  docs alone.
- **`minApiLevel="3.4.0"`** in `manifest.xml` — a reasonable guess for the
  Weather module APIs used; the VS Code extension will tell you if it needs
  to be higher, and can usually bump it for you.
- **`Weather.CONDITION_*` constants** in `HudDraw.mapConditionToBucket()` — I
  used a conservative subset that's been in the API since Weather's original
  3.1.0 release. There are ~50 more granular constants (see the
  [Weather API docs](https://developer.garmin.com/connect-iq/api-docs/Toybox/Weather.html))
  if you want finer icon distinctions later.
- Field layout (`w * 0.22` etc. fractions in `ApacheWatchFaceView.mc`) was
  tuned by eye for a round display — nudge the fractions if anything clips
  near the bezel on your actual screen.

## Customizing

- Colors: `source/ColorScheme.mc`.
- Field positions/sizes: the `w * 0.NN` / `h * 0.NN` fractions in each
  `draw*Field` method in `source/ApacheWatchFaceView.mc`.
- Icon shapes: `source/HudDraw.mc`.
- Refresh intervals: the constants at the top of `source/DataCache.mc`.

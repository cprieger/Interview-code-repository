# AH-64E Apache Watch Face

A Garmin Connect IQ watch face for the **fenix 7X Pro Sapphire Solar**, styled as a
phosphor-green LCD/HUD readout: a big always-24-hour digital clock centered in the
display, with octagon-cut ("clipped corner") panels for each stat group, dashed
segment-style dividers under each stat row, and monospace/digital numerals — the
look of an old amber/green cockpit MFD rendered on a modern round MIP display.

Everything is drawn programmatically (no bitmap art besides the launcher icon) —
flat fills, no gradients, legible on the watch's MIP display.

**Status: builds and runs clean.** This has been compiled with the real Connect IQ
SDK (monkeyc) and run in the simulator (monkeydo) for both `fenix7xpro` and
`fenix7xpronowifi` with no crashes. Local environment is already set up on this
machine — see below.

## Local environment (already set up here)

| Component | Location |
|---|---|
| Connect IQ SDK 9.2.0 | `%APPDATA%\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.2.0-2026-06-09-92a1605b2\` |
| Device files (fenix7xpro + fenix7xpronowifi, incl. simulator fonts) | `%APPDATA%\Garmin\ConnectIQ\Devices\` |
| Developer signing key | `~/.garmin/developer_key.der` (outside the repo — never commit it) |
| Microsoft OpenJDK 17 (required by monkeyc) | `C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot\` |
| VS Code Monkey C extension (`garmin.monkey-c`) | installed |
| [connect-iq-sdk-manager](https://github.com/lindell/connect-iq-sdk-manager-cli) CLI, used to fetch the SDK/devices/fonts headlessly | `C:\Users\Chris\bin\connect-iq-sdk-manager.exe` |

To build from a fresh terminal (PATH isn't persisted automatically):

```bash
export PATH="/c/Program Files/Microsoft/jdk-17.0.19.10-hotspot/bin:$PATH"
SDK_BIN="/c/Users/Chris/AppData/Roaming/Garmin/ConnectIQ/Sdks/connectiq-sdk-win-9.2.0-2026-06-09-92a1605b2/bin"
cd apps/apache-watchface
"$SDK_BIN/monkeyc.bat" -o bin/apache-watchface.prg -f monkey.jungle \
  -y "/c/Users/Chris/.garmin/developer_key.der" -d fenix7xpro -w
```

Or just open the folder in VS Code and use `Monkey C: Build for Device` /
`Monkey C: Run` — the extension already knows about the installed SDK.

## What's on screen

| Position | Field |
|---|---|
| Center (largest, most generous sizing) | Hours : Minutes in **24-hour format, always** (not tied to the device's 12/24h setting), with smaller Seconds beside it (seconds hidden in Always-On mode) |
| Top left | Battery %, segmented (4-bar) fill icon |
| Top right | Heart rate, red heart icon |
| Bottom left | Step count, footprint icon |
| Bottom right | Next solar event (sunrise before sunrise, sunset after), amber sun-on-horizon icon with rise/set arrow |
| Bottom center | Date, e.g. `WED 08/07` (format configurable in Garmin Connect app settings) |
| Very bottom | Temperature + weather icon (sunny/cloudy/rain/snow/storm) |

Row sizing follows an explicit priority order (client-specified): clock+seconds is
biggest and most legible, then temp/weather, then next solar event, then heart rate,
then step count, then battery % — the PWR/HR row sits furthest from screen center
(tightest against the round bezel) and is sized/laid out accordingly.

Day mode: phosphor green (`0x8CFF6E`) text/icons on black, amber accent for the solar
icon, red accent for the heart icon. Always-On mode: single dim green (fully
monochrome, no accent hues), seconds hidden, weather icon simplified to sunny/cloudy,
heart rate and weather refresh less often. There is no decorative outer ring/gauge —
an earlier concept pass had one and it was removed; nothing but the 7 spec fields and
their panel framing is drawn.

## 1. Set up your local environment (on another machine)

Already done on this machine (see above). On a different machine — e.g. if your
brother wants to build it himself rather than just receiving a `.prg` — here's what's
needed:

1. **Install the SDK Manager GUI**, from the
   [Connect IQ SDK page](https://developer.garmin.com/connect-iq/sdk/), *or* the
   [connect-iq-sdk-manager CLI](https://github.com/lindell/connect-iq-sdk-manager-cli)
   (what was used here — scriptable, but it's a third-party tool, not Garmin's own).
   Either way it's gated behind a free Garmin account login + accepting Garmin's SDK
   license.
2. **Install a JDK** (Java 17+) — the compiler (`monkeyc`) is a JVM tool and won't run
   without one. [Microsoft's OpenJDK 17](https://learn.microsoft.com/en-us/java/openjdk/download)
   is a safe, official pick.
3. **Install the SDK + device files, including fonts.** If using the CLI:
   `connect-iq-sdk-manager device download --manifest=manifest.xml --include-fonts`
   — the `--include-fonts` flag is easy to miss and its absence causes a
   confusing runtime crash (`Invalid Font Specified`) that has nothing to do with
   which font you picked in code; see "Bugs found" below.
4. **Install VS Code + the Monkey C extension** (`garmin.monkey-c`) — Garmin's
   current official toolchain (the old Eclipse IDE is deprecated).
5. **Generate a developer key** (one-time): `openssl genrsa -out developer_key.pem 4096`
   then `openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt`.
   Keep it outside any repo — **never commit it**.
6. **Device id**: both `fenix7xpro` and `fenix7xpronowifi` in `manifest.xml` are
   confirmed valid — both downloaded and compiled successfully, so no manifest edit
   is needed regardless of which exact fenix 7X Pro variant you have.

## 2. Build & run in the simulator

- Command palette → `Monkey C: Run` → pick **fenix7xpro** (or whichever id you
  kept) → this builds and launches the Connect IQ Simulator.
- In the simulator, use the **Sensors** menu to fake heart rate/step data, and
  the **location** picker so `Weather`/sunrise-sunset have something to compute
  from (both are `null`-safe in the code — they'll just show `--` until a
  location/weather source is available).
- Toggle Always-On mode from the simulator's watch-face menu to check the
  monochrome/seconds-hidden styling.

## 3. Sideload to your watch (or send the `.prg` to someone else)

1. Command palette → `Monkey C: Build for Device` → produces a `.prg` in `bin/`.
2. Connect the watch by USB — it mounts as a mass-storage drive.
3. Copy the `.prg` into `GARMIN/APPS/` on the watch.
4. Eject/disconnect. The watch face appears in your watch face list within a
   few seconds.

(Garmin Express can also push it, but the drag-and-drop above is simpler for
iterating during development.)

**A compiled `.prg` is just a file — you can email it, and no device needs to be
plugged into this machine for that.** Building only needs the SDK; installing only
needs *the target watch* plugged into *whichever* computer is doing the install. So:
compile once here, send the `.prg` to your brother, and he plugs his own watch into
his own computer and drags it into `GARMIN/APPS/` — same 4 steps above, just on his
end. The one requirement: his watch has to be the same device id this was built for
(`fenix7xpro` / `fenix7xpronowifi`) — a `.prg` is device-specific, it won't install
on a different Garmin model. If he has a different watch, add his device id to
`manifest.xml` and rebuild.

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
insignia in the code or icon — it's just a cockpit-instrument *aesthetic*
(phosphor-green digital numerals, octagon-cut panel framing, dashed dividers).
Keep the store listing's name and description generic ("phosphor HUD watch
face" rather than "AH-64E Apache watch face") to stay clear of any trademark
issue, especially since this is a public store submission and not just a
personal sideload.

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

## Bugs found and fixed during the real compile/run pass

This was first written without the SDK available, then actually compiled and run in
the simulator. Six real issues turned up, now all fixed:

- `private function` inside a `module` (`HudDraw.mc`) — Monkey C's `module` doesn't
  support access modifiers, only `class` does. Compile error.
- Missing `import Toybox.Lang;` in `ColorScheme.mc` — `Number`/`Boolean` type
  annotations don't resolve without it. Compile error.
- `getInitialView()` return type — the base class expects the tuple-array syntax
  `[Views] or [Views, InputDelegates]`, not `Array<Views or InputDelegates>`.
  Compile error.
- `fillPolygon()` point arrays need the tuple type `Array<[Numeric, Numeric]>`, not
  a generic `Array<Array<Numeric>>`. Compile error.
- `settings.xml` used a `list` setting config bound to a `boolean` property (for the
  DD/MM vs MM/DD picker) — Connect IQ only allows `list` on `number`/`string`
  properties. Switched `dateFormatDDMM` to a `number` property (1/0).
- **Runtime crash**, not a compile error: `Invalid Font Specified` on the very first
  `drawText()` call, regardless of which font constant was used. Root cause: device
  *fonts* are a separate downloadable component from the device profile and SDK —
  downloading device support without `--include-fonts` leaves the simulator with
  font metadata but no actual glyph data. Fixed by re-running device download with
  fonts included. If you ever see this exact error on a fresh device install, this
  is almost certainly why.

Field layout in `ApacheWatchFaceView.mc` is computed against real round-display
geometry, not eyeballed fractions: the whole content stack (PWR/HR, clock, STP/SOLAR,
date, WX) is centered vertically as a block, and each row's usable half-width is
`safeHalfWidth()` — `sqrt(contentR² - dy²)` for that row's vertical distance `dy` from
center — rather than a flat fraction of screen width. This has been visually verified
by compiling, running in `monkeydo`, and screenshotting the actual simulator window
(native Win32 `PrintWindow` capture, not a browser tool) — not just assumed from a
clean compile. If you retune the row-height fractions, re-verify the same way: a
`BUILD SUCCESSFUL` says nothing about whether an icon is actually visible or two
fields are overlapping at the real on-device size.

The `Weather.CONDITION_*` subset used in `HudDraw.mapConditionToBucket()` is
deliberately conservative (constants present since Weather's original 3.1.0
release) — there are ~50 more granular constants in the
[Weather API docs](https://developer.garmin.com/connect-iq/api-docs/Toybox/Weather.html)
if you want finer icon distinctions later.

## Customizing

- Colors: `source/ColorScheme.mc`.
- Field positions/sizes: the row-height fractions of `r` (display radius) at
  the top of `onUpdate()`, and the per-row `draw*Row` methods, in
  `source/ApacheWatchFaceView.mc`.
- Icon shapes: `source/HudDraw.mc`.
- Refresh intervals: the constants at the top of `source/DataCache.mc`.

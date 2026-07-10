# CLAUDE.md — AH-64E Tactical Watch Face

Context file for `apps/apache-watchface/`. Loaded automatically when working in this
directory. Read this before touching the code — it captures a lot of hard-won,
non-obvious API behavior that isn't visible from the source alone.

---

## What this is

A Garmin Connect IQ watch face for the **fenix 7X Pro Sapphire Solar**, built for a
real client (an AH-64E Apache flight-school pilot) who wanted a "tacticool" military
MFD/HUD aesthetic — phosphor-green digital readouts, chamfered panel chrome, a
red dagger-through-heart HR icon, yellow/orange sunrise/sunset icons. Not a generic
hobby project — every design choice traces back to explicit client feedback across
5 shipped versions (see `CHANGELOG.md` root-level entries dated 2026-07-08/09).

**Current state:** V5 is the latest, on branch `cprieger/add-apache-watchface`,
**PR #9 open against `main`, not yet merged**. Security review already completed
on the full diff (no findings — see PR description). Versioned build artifacts for
every shipped iteration live in `bin/` (`apache-watchface-v1.prg` through `-v5.prg`,
gitignored but kept on disk) — client copies these out directly rather than us
re-sending each time; **never overwrite an existing `-vN.prg`, always cut a new one**.

**Known open item:** client asked to also compile for a **fenix 5X**. This was
being investigated when interrupted — do not assume it's a quick add. The fenix 5X
reports **API level 3.1** (`connect-iq-sdk-manager device list`), while this
manifest requires `minApiLevel="3.4.0"` and the code uses `Graphics.getVectorFont()`
and `Dc.drawScaledBitmap()`, both of which may not exist at 3.1. The whole layout is
also a **fixed pixel matrix tuned for 280x280** (fenix 7X Pro's real resolution) —
fenix 5X's screen is a different, smaller resolution. Compiling for it will very
likely need either a second manifest/build variant with its own coordinate matrix
and font fallbacks, or a device-resolution-aware rewrite. Verify the 5X's actual
`compiler.json` screen size and API-gated symbols before assuming anything works.

---

## Local Environment (already set up on this machine)

| Component | Path |
|---|---|
| Connect IQ SDK 9.2.0 | `C:\Users\Chris\AppData\Roaming\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.2.0-2026-06-09-92a1605b2\` |
| Device files (fenix7xpro + fenix7xpronowifi, + simulator fonts) | `C:\Users\Chris\AppData\Roaming\Garmin\ConnectIQ\Devices\` |
| Developer signing key | `C:\Users\Chris\.garmin\developer_key.der` (outside the repo — **never commit it**) |
| Microsoft OpenJDK 17 (required by `monkeyc`) | `C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot\` |
| `connect-iq-sdk-manager` CLI (headless SDK/device/font downloads) | `C:\Users\Chris\bin\connect-iq-sdk-manager.exe` |

Compile + run loop (Git Bash):
```bash
export PATH="/c/Program Files/Microsoft/jdk-17.0.19.10-hotspot/bin:$PATH"
SDK_BIN="/c/Users/Chris/AppData/Roaming/Garmin/ConnectIQ/Sdks/connectiq-sdk-win-9.2.0-2026-06-09-92a1605b2/bin"
cd apps/apache-watchface
"$SDK_BIN/monkeyc.bat" -o bin/apache-watchface.prg -f monkey.jungle \
  -y "/c/Users/Chris/.garmin/developer_key.der" -d fenix7xpro -w
```
To actually run it and catch runtime crashes (**a clean compile proves nothing** —
see Verification below):
```bash
"$SDK_BIN/simulator.exe" &        # start once, leave running
sleep 5
"$SDK_BIN/monkeydo.bat" bin/apache-watchface.prg fenix7xpro
```
`monkeydo` prints nothing and holds the connection open on success; it prints an
`Error:` block and exits immediately on a runtime crash.

**Screenshotting the simulator** — `SetForegroundWindow` + `CopyFromScreen` is
unreliable (grabbed an unrelated window sharing the desktop once this session,
since it depends on window focus/z-order). Use native `PrintWindow` instead, which
captures a window's contents directly regardless of focus:
```powershell
Add-Type @"
using System; using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdc, uint flags);
    public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
Add-Type -AssemblyName System.Drawing
$proc = Get-Process | Where-Object { $_.ProcessName -like "*simulator*" } | Select-Object -First 1
$hwnd = $proc.MainWindowHandle
$rect = New-Object Win32+RECT
[Win32]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
$w = $rect.Right - $rect.Left; $h = $rect.Bottom - $rect.Top
$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc(); [Win32]::PrintWindow($hwnd, $hdc, 2) | Out-Null; $g.ReleaseHdc($hdc)
$bmp.Save("<path>.png", [System.Drawing.Imaging.ImageFormat]::Png)
```

---

## Architecture

| File | Purpose |
|---|---|
| `manifest.xml` | App id, target device(s), `minApiLevel`, permissions (`Positioning`) |
| `monkey.jungle` | Build config (source/resource paths) |
| `source/ApacheWatchFaceApp.mc` | App entry point (`getInitialView()`) |
| `source/ApacheWatchFaceView.mc` | The whole draw loop — fixed pixel coordinate matrix, per-field `draw*Box()` methods, sleep/wake handling |
| `source/DataCache.mc` | Throttled sensor/weather/solar-event refresh (weather 15/45min awake/asleep, HR 5/60s, solar once/day) |
| `source/HudDraw.mc` | Vector chrome (chamfered panel outlines, battery fill rect) + bitmap-drawing helpers (`drawBitmapCentered`, `drawBitmapScaledCentered`) |
| `source/ColorScheme.mc` | Single-hue tactical-green day/AOD palette + the one dynamic override (battery-critical red) |
| `source/Fonts.mc` | `Graphics.getVectorFont()` wrappers per text role, with fallback to fixed `Graphics.FONT_*` enums |
| `resources/drawables/hud/*.png` | Pre-rendered, anti-aliased bitmap icons (see "Icon generation" below) |
| `tools/generate_hud_icons.py` | Regenerates every icon in `resources/drawables/hud/` |
| `tools/generate_launcher_icon.py` | Regenerates the launcher icon |
| `bin/apache-watchface-vN.prg` | Versioned, client-facing build artifacts — one per shipped iteration |

---

## The Playbook: building another watch face like this

This project's actual methodology, if you're starting a new watch face from
scratch. Follow this order — it's the order that avoided the most rework.

### 1. Icons are bitmaps, not live vector draws

Monkey C's `Dc.fillPolygon()`/`fillCircle()` have **no anti-aliasing** on a real
MIP display — hand-drawn icons read as crude/blobby at real on-device icon sizes
(20-30px). Instead: generate icons with **Python + Pillow**, drawn at **4x
supersampling then downsampled** (the standard "design big, ship small" technique —
`tools/generate_hud_icons.py` has a `canvas()`/`finish()` helper pair that does
this automatically). Bake **separate day-mode and Always-On-mode color variants**
as separate PNG files — Monkey C has no runtime bitmap tint API, so you cannot
recolor one bitmap at draw time.

Load every bitmap resource **once**, in `initialize()`/`onLayout()`, cache in
instance variables. Draw with `Dc.drawBitmap(x, y, ref)` (top-left corner) or, if
the on-screen size needs to differ from the asset's native resolution,
`Dc.drawScaledBitmap()` via `HudDraw.drawBitmapScaledCentered()` —
**`drawBitmapCentered()` only centers, it does NOT scale**. Mixing these up was a
real, repeated bug this project hit twice (boot icon, then solar icon) — changing
a `*_W`/`*_H` constant used only for centering math does nothing to the actual
rendered bitmap size.

### 2. Fixed pixel matrix > proportional layout, for a single target device

If you're targeting one specific device (know its exact resolution), a literal
`(X, Y, W, H)` constant per field, verified against real corner-distance math, beats
a "clever" proportional/dynamic layout — it's easier to reason about field-by-field
client feedback ("move the clock 10px right") when every position is a named
constant, not a computed fraction.

**The corner-distance check, every time you place or resize a box**, for a round
display with center `(cx, cy)` and bezel radius `r`:
```
worst_corner_dist = sqrt(max(|left-cx|, |right-cx|)^2 + max(|top-cy|, |bottom-cy|)^2)
```
This must be `< r` with margin (this project used a ≥6px convention) for **every**
corner, not just the ones that look close by eye. This project's V2 first pass had
three boxes with corners **21px, 13px, and ~1px past the true edge** — invisible in
the code, obvious once measured, and the actual root cause of a client "text is
overlapping/unclear" complaint that first looked like a font-size problem.

### 3. One hue, one dynamic override

A single tactical-green palette (`ColorScheme.mc`) for both day and Always-On
(different brightness of the *same* hue, not different hues) reads as more
deliberate/military than a rainbow of per-field accent colors — and it's what the
client explicitly asked for after seeing a busier first draft. The **one** exception
this project has is battery-critical (<15%) turning red — a genuine alert, not
decoration. If a later version asks for per-field accents back (this project's V4,
"color variant" — red heart, yellow/orange solar), treat it as a deliberate,
separate visual mode, not a reversion of the monochrome rule.

### 4. Custom fonts: expect to fail, have a fallback ready

Client specs asking for a "custom font family" almost always mean a fictional/
unavailable typeface. **Connect IQ's `<font>` resource pipeline wants a pre-rendered
AngelCode BMFont atlas, not a raw TTF** — a real attempt this session to compile a
`.ttf` as a font resource failed with `Unable to process 'font' resources: "9B" is
not a valid key/value pair` (the compiler tried to parse the TTF binary header as
BMFont text). The working fallback: `Graphics.getVectorFont({:face=>.., :size=>N})`
— a real, currently-supported vector font engine (check the target device's
`compiler.json` `digitalFonts` list for available face names; this project uses
`sourceSansPro` for numeric fields, `leagueGothic` for stencil/header fields on
fenix7xpro). Always wrap in try/catch with a fixed `Graphics.FONT_*` fallback in
case a face name doesn't resolve on some device/firmware (`Fonts.mc:load()`).

### 5. Verify everything by actually compiling, running, and screenshotting

**Never report a change as "done" off a clean compile alone.** This project hit
both failure modes:
- **Compiles clean, crashes at runtime**: a missing font-resource download
  (`--include-fonts` flag) caused `Invalid Font Specified` on the very first
  `drawText()` call, unrelated to which font was actually used.
- **Compiles and runs clean, silently wrong**: the weather icon simply didn't
  render (coordinate bug); the boot/solar icon "resize" bugs above didn't crash,
  they just silently didn't resize.

The only thing that catches both is: compile → `monkeydo` (check for the `Error:`
block) → screenshot the actual simulator window → look at it. For layout/overflow
fixes specifically, **force worst-case display values** temporarily
(`"88:88"`, `"100%"`, a long label) to verify a fix holds under the hardest case,
not just whatever the simulator happens to be showing — then revert the temporary
override before committing. Mark temp overrides with a greppable comment tag
(this project used `V5-TEST-OVERRIDE:`) so you can `grep` and confirm none are left
in before shipping — a prior pass left one in by accident (`timeStr = "00:00"`, a
hardcoded debug override) and it was only caught by a careful re-read, not by CI.

### 6. Client corrections supersede your own guesses — check what actually landed

When a client says "instead of guessing, let me tell you," they're not just giving
new numbers — they're telling you your own prior guess for that specific field is
wrong, but everything else you did (that they didn't mention) usually still stands.
Re-read the current file state before making the correction; don't assume you
remember what you last wrote, and don't silently redo work they didn't ask you to
redo.

---

## Mobius: the Garmin watch face specialist agent

`.claude/agents/mobius.md` (repo root) is a persistent sub-agent built for exactly
this kind of work — it has its own copy of the toolchain paths, the design spec,
and the Monkey C gotchas above. Use it (via the `Agent` tool, `subagent_type:
"mobius"`) for Connect IQ-specific implementation work (wiring bitmaps, retuning
layout, fixing compile errors) — but **icon *design*/generation (the Python/Pillow
work) is not its job**, do that directly. Mobius's own doc has a "Current Sprint"
section — keep it updated if you hand it a new multi-step task, the same way this
file should stay current for whoever reads it next.

---

## Git Workflow

Same convention as the repo root `CLAUDE.md`: never commit to `main` directly,
branch is `cprieger/<descriptive-name>`, update `CHANGELOG.md` (root-level, dated
entries) with every change before opening/updating a PR. This app's PR is **#9,
already open** — new work should land as additional commits on
`cprieger/add-apache-watchface` and get pushed, not a new branch, unless the
client explicitly starts a new versioned effort (e.g. a "V6").

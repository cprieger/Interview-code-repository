import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.ActivityMonitor;
import Toybox.Application.Properties;

// V2: fixed pixel coordinate matrix for the real 280x280 fenix7xpro panel
// (center 140,140 / bezel radius 140) - replaces V1's dynamic
// safeHalfWidth()/circle-geometry row layout with the client's literal
// per-field boxes.
//
// V2.1 client feedback (real screenshot): text overlapping/unclear. Redid
// every box's corner-distance math against the true 140px bezel radius
// (worst corner = sqrt(max(|left-cx|,|right-cx|)^2 + max(|top-cy|,|bottom-cy|)^2))
// instead of eyeballing, and found the V2 literal spec numbers put THREE
// boxes' corners genuinely outside/at the visible circle, not just tight:
// Battery/HR corner was ~161px from center (21px past the 140px edge),
// Date's bottom corners were ~153px (13px past), Steps/Solar/Weather/Title
// were all within ~0-1.4px of the edge (effectively zero margin). That's
// a real source of the "overlapping/unclear" complaint - box borders and
// text were being cut by the round bezel mask, not just crowded.
//
// Every box below was resized/repositioned to a verified >=6px corner
// margin from the true edge (most land at 8-13px), narrowing width being
// the main lever (frees far more margin per pixel than moving vertically,
// since horizontal offset and vertical offset both feed the same corner
// dist formula, and rows this close to the top/bottom already spend most
// of their radius budget on the vertical term). Real geometry/render
// limits found in the process, all honored rather than argued with:
//   - The title banner and Weather box sit so close to the top/bottom pole
//     of the circle that "push up/down AND stay margin-safe" trade off
//     directly - narrowing bought far more safety per pixel than moving
//     vertically did, so the title mostly got narrower with only a small
//     (2px) up-nudge, not a dramatic one.
//   - A real screenshot of an initial Weather-box "push down" (Y=252)
//     showed the Footer text below it rendering visibly dim/soft compared
//     to every other field on the exact same font - the round display's
//     physical edge curvature/mask softens content in roughly the last
//     15px of radius regardless of what the literal square-canvas corner
//     math says, and that isn't captured by the formula above. Both boxes
//     were pulled back toward center instead (Weather net 2px UP from
//     V2's original position, Footer 2px up from V2's), prioritizing an
//     actually-legible result over the literal direction of the nudge.
//   - The Solar box's "NEXT SOLAR" label overflowed past its own right
//     border once the box was narrowed - caught in the same screenshot,
//     fixed by shortening the label to "SOLAR" (matches the terseness of
//     every other box label: PWR/HR/STP) rather than widening the box
//     back out.
// Removing the outer chapter-ring tick gauge (dead code, gone from
// HudDraw.mc/onUpdate() - client called it "the weird ring around the
// edge") didn't directly free pixels for these boxes (the ring was a
// background layer other boxes already drew over), but it does mean the
// outer band of the face is no longer visually competing with tick marks,
// so the added vertical gap around the clock (top row -> clock gap grew
// 6px -> 12px) actually reads as breathing room instead of clutter.
class ApacheWatchFaceView extends WatchUi.WatchFace {
    private const DAY_ABBREV as Array<String> = ["", "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];

    // Native bitmap pixel dimensions - fixed-size assets, sized/positioned
    // by the box layout below rather than scaled at runtime (except where
    // a box is explicitly too small for the native asset - Weather/BT/Bell
    // use HudDraw.drawBitmapScaledCentered() for that reason, noted at
    // their call sites).
    private const BATTERY_W = 34.0;
    private const BATTERY_H = 18.0;
    private const HEART_W = 28.0;
    private const HEART_H = 28.0;
    private const BOOT_W = 36.0;
    // Grew 24->32: boot icon now includes an ankle shaft on top
    // (client: "give it like a little top to the boot").
    private const BOOT_H = 32.0;
    private const SOLAR_W = 28.0;
    private const SOLAR_H = 28.0;
    private const WX_W = 32.0;
    private const WX_H = 32.0;
    private const BANNER_W = 220.0;
    private const BANNER_H = 52.0;
    private const BT_W = 22.0;
    private const BT_H = 22.0;
    private const BELL_W = 24.0;
    private const BELL_H = 24.0;

    // ---- V2.1 pixel coordinate matrix (margin-verified against the real
    // 140px bezel radius - see the class-level comment above for the full
    // corner-distance methodology and what was wrong with the V2 numbers) ----
    private const TITLE_BOX_X = 110.0;
    private const TITLE_BOX_Y = 12.0;
    private const TITLE_BOX_W = 60.0;
    private const TITLE_BOX_H = 14.0;

    private const BATT_BOX_X = 70.0;
    private const BATT_BOX_Y = 28.0;
    private const BATT_BOX_W = 64.0;
    private const BATT_BOX_H = 44.0;

    private const HR_BOX_X = 146.0;
    private const HR_BOX_Y = 28.0;
    private const HR_BOX_W = 64.0;
    private const HR_BOX_H = 44.0;

    // Client feedback: box had too much left/right padding - narrowed 6px
    // per side (236 -> 224), re-centered on the same 140px axis (22+6=28,
    // 28+224=252, center still 140).
    private const CLOCK_BOX_X = 28.0;
    private const CLOCK_BOX_Y = 84.0;
    private const CLOCK_BOX_W = 224.0;
    private const CLOCK_BOX_H = 72.0;

    private const STEPS_BOX_X = 36.0;
    private const STEPS_BOX_Y = 166.0;
    // Client: "go 2 more numbers in, from 123 basically to 150 as the end
    // x coordinate" - widened so the box's right edge lands at X=150
    // (was 36+88=124), giving the step-count value more room.
    private const STEPS_BOX_W = 114.0;
    private const STEPS_BOX_H = 46.0;

    private const SOLAR_BOX_X = 156.0;
    private const SOLAR_BOX_Y = 166.0;
    private const SOLAR_BOX_W = 88.0;
    private const SOLAR_BOX_H = 46.0;

    // Date box: was (34,216,212,34) in V2 - bottom corners measured ~153px
    // from center against the 140px bezel radius (13px past the edge).
    // Narrowed to a verified ~13px margin; Y left essentially where it was
    // (216->218, a 2px fine-tune, not a deliberate push - Date wasn't part
    // of the "push down" list, only the margin-fix list).
    // DATE_BOX_H trimmed 28 -> 22 as a direct companion to halving the date
    // font (Fonts.dateFont 16->8px): the box had only a 2px gap to the
    // Weather box below it, not enough room to grow/raise the Weather row
    // per client feedback without this. The much smaller font leaves the
    // box mostly empty vertically anyway, so shaving 6px off the bottom
    // (Y kept at 218, only the bottom edge moves 246->240) frees that
    // margin without changing the date row's on-screen position/corner.
    private const DATE_BOX_X = 70.0;
    private const DATE_BOX_Y = 218.0;
    private const DATE_BOX_W = 140.0;
    private const DATE_BOX_H = 22.0;

    // Weather box: was (80,250,120,18) in V2, corners ~1.4px past the
    // bezel edge. This box sits closest to the bottom pole of the circle,
    // the same tight-geometry situation as the Title box at the top pole -
    // narrowing bought far more margin per pixel than moving down did.
    //
    // A real screenshot of an initial "push down" attempt (Y=252) showed
    // the Footer text below it rendering visibly dim/soft compared to
    // every other field using the exact same font - the round display's
    // physical edge curvature/mask starts softening content in that last
    // ~15px band regardless of the literal square-canvas math, which
    // corner-distance alone doesn't capture. Pulled back up to Y=248 (2px
    // net UP from V2's original 250, not down) so the Footer below it has
    // real clearance from that band - legibility over the literal
    // direction of the nudge, since an unclear footer is exactly the
    // defect this pass is fixing.
    //
    // Client polish pass: "bigger, moved up a few pixels". Y 248->243 (5px
    // up, freed by trimming DATE_BOX_H above - verified >=3px gap to the
    // date box's new bottom edge at Y=240) and H 16->20 (+4, bottom edge
    // ends up at 263, 1px net UP from the old 264, so the Footer below
    // still keeps its clearance). Icon/temp-text size increase is driven
    // off WX_BOX_H directly (see drawWeatherBox) so no separate constant
    // needed for that part.
    //
    // W also widened 80->88 (X 100->96, still centered on 140) - a real
    // screenshot at the original 80px width showed the bigger icon and
    // bigger temp text colliding (icon's right edge landed inside the "5"
    // of the temperature), since both grew toward each other with no
    // extra horizontal room. The wider box fixes that with real clearance
    // confirmed in a follow-up screenshot. Bottom-corner bezel margin
    // re-checked with the new width: worst corner (96,263) is ~130.6px
    // from the true (140,140)/r=140 center, a 9.4px margin - still safely
    // inside the >=6px convention used throughout this matrix.
    private const WX_BOX_X = 96.0;
    private const WX_BOX_Y = 243.0;
    private const WX_BOX_W = 88.0;
    private const WX_BOX_H = 20.0;

    // Footer: moved up to Y=268 (was 270 in V2) for the same reason as the
    // Weather-box pullback above - a real screenshot showed this field
    // rendering dim/unclear right at the literal canvas edge (bottom=280),
    // even though the corner-distance math alone looked acceptable. Kept
    // clearly clear of that edge instead (bottom=276, 4px shy of 280).
    //
    // Client polish pass: nudged up another 2px (268->266) per "move up a
    // few pixels off the bottom edge" - keeps a 3px gap to the Weather
    // box's new bottom (263) and actually increases clearance to the
    // canvas edge (280) from 4px to 6px, so this is strictly safer than
    // before, not just different.
    private const FOOTER_CX = 140.0;
    private const FOOTER_Y = 266.0;
    private const FOOTER_H = 8.0;

    private var _cache as DataCache;
    private var _isSleeping as Boolean = false;
    private var _iconsLoaded as Boolean = false;

    // Day/Always-On bitmap pairs, loaded once (see loadIcons()) and cached
    // here rather than reloaded on every onUpdate() call.
    private var _iconBatteryChromeDay as Graphics.BitmapType?;
    private var _iconBatteryChromeAod as Graphics.BitmapType?;
    private var _iconHeartDay as Graphics.BitmapType?;
    private var _iconHeartAod as Graphics.BitmapType?;
    private var _iconBootDay as Graphics.BitmapType?;
    private var _iconBootAod as Graphics.BitmapType?;
    private var _iconSolarRiseDay as Graphics.BitmapType?;
    private var _iconSolarSetDay as Graphics.BitmapType?;
    private var _iconSolarRiseAod as Graphics.BitmapType?;
    private var _iconSolarSetAod as Graphics.BitmapType?;
    private var _iconWxClearDay as Graphics.BitmapType?;
    private var _iconWxCloudyDay as Graphics.BitmapType?;
    private var _iconWxOvercastDay as Graphics.BitmapType?;
    private var _iconWxRainDay as Graphics.BitmapType?;
    private var _iconWxSnowDay as Graphics.BitmapType?;
    private var _iconWxStormDay as Graphics.BitmapType?;
    private var _iconWxClearAod as Graphics.BitmapType?;
    private var _iconWxOvercastAod as Graphics.BitmapType?;
    private var _bannerAh64e as Graphics.BitmapType?;
    private var _iconBluetoothDay as Graphics.BitmapType?;
    private var _iconBluetoothAod as Graphics.BitmapType?;
    private var _iconBellDay as Graphics.BitmapType?;
    private var _iconBellAod as Graphics.BitmapType?;

    function initialize() {
        WatchFace.initialize();
        _cache = new DataCache();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        loadIcons();
    }

    // Loads every HUD bitmap resource exactly once. Called from onLayout()
    // (guaranteed to run before the first onUpdate()); guarded by
    // _iconsLoaded in case the system ever calls onLayout() more than once,
    // so resources are never redundantly reloaded.
    private function loadIcons() as Void {
        if (_iconsLoaded) {
            return;
        }

        _iconBatteryChromeDay = WatchUi.loadResource(Rez.Drawables.IconBatteryChromeDay) as Graphics.BitmapType;
        _iconBatteryChromeAod = WatchUi.loadResource(Rez.Drawables.IconBatteryChromeAod) as Graphics.BitmapType;

        _iconHeartDay = WatchUi.loadResource(Rez.Drawables.IconHeartDay) as Graphics.BitmapType;
        _iconHeartAod = WatchUi.loadResource(Rez.Drawables.IconHeartAod) as Graphics.BitmapType;

        _iconBootDay = WatchUi.loadResource(Rez.Drawables.IconBootDay) as Graphics.BitmapType;
        _iconBootAod = WatchUi.loadResource(Rez.Drawables.IconBootAod) as Graphics.BitmapType;

        _iconSolarRiseDay = WatchUi.loadResource(Rez.Drawables.IconSolarRiseDay) as Graphics.BitmapType;
        _iconSolarSetDay = WatchUi.loadResource(Rez.Drawables.IconSolarSetDay) as Graphics.BitmapType;
        _iconSolarRiseAod = WatchUi.loadResource(Rez.Drawables.IconSolarRiseAod) as Graphics.BitmapType;
        _iconSolarSetAod = WatchUi.loadResource(Rez.Drawables.IconSolarSetAod) as Graphics.BitmapType;

        _iconWxClearDay = WatchUi.loadResource(Rez.Drawables.IconWxClearDay) as Graphics.BitmapType;
        _iconWxCloudyDay = WatchUi.loadResource(Rez.Drawables.IconWxCloudyDay) as Graphics.BitmapType;
        _iconWxOvercastDay = WatchUi.loadResource(Rez.Drawables.IconWxOvercastDay) as Graphics.BitmapType;
        _iconWxRainDay = WatchUi.loadResource(Rez.Drawables.IconWxRainDay) as Graphics.BitmapType;
        _iconWxSnowDay = WatchUi.loadResource(Rez.Drawables.IconWxSnowDay) as Graphics.BitmapType;
        _iconWxStormDay = WatchUi.loadResource(Rez.Drawables.IconWxStormDay) as Graphics.BitmapType;
        _iconWxClearAod = WatchUi.loadResource(Rez.Drawables.IconWxClearAod) as Graphics.BitmapType;
        _iconWxOvercastAod = WatchUi.loadResource(Rez.Drawables.IconWxOvercastAod) as Graphics.BitmapType;

        _bannerAh64e = WatchUi.loadResource(Rez.Drawables.BannerAh64e) as Graphics.BitmapType;

        _iconBluetoothDay = WatchUi.loadResource(Rez.Drawables.IconBluetoothDay) as Graphics.BitmapType;
        _iconBluetoothAod = WatchUi.loadResource(Rez.Drawables.IconBluetoothAod) as Graphics.BitmapType;
        _iconBellDay = WatchUi.loadResource(Rez.Drawables.IconBellDay) as Graphics.BitmapType;
        _iconBellAod = WatchUi.loadResource(Rez.Drawables.IconBellAod) as Graphics.BitmapType;

        _iconsLoaded = true;
    }

    function onShow() as Void {
    }

    function onHide() as Void {
    }

    function onExitSleep() as Void {
        _isSleeping = false;
    }

    function onEnterSleep() as Void {
        _isSleeping = true;
        WatchUi.requestUpdate();
    }

    // No onPartialUpdate() override: seconds (the one per-second element)
    // are hidden in Always-On mode, so there's nothing that needs a
    // per-second redraw while sleeping - the system's default low-power
    // fallback of calling onUpdate() once a minute is exactly right here,
    // for free. The V2.1 margin/spacing rework doesn't change this.
    function onUpdate(dc as Graphics.Dc) as Void {
        _cache.refresh(_isSleeping);

        dc.setColor(Graphics.COLOR_WHITE, ColorScheme.BACKGROUND);
        dc.clear();

        var textColor = ColorScheme.textColor(_isSleeping);
        var panelColor = ColorScheme.panelColor(_isSleeping);

        if (!_isSleeping) {
            drawTitleBanner(dc);
        }

        var battery = System.getSystemStats().battery;
        var battColor = ColorScheme.batteryColor(_isSleeping, battery);
        drawBatteryBox(dc, battery, battColor);
        drawHeartRateBox(dc, textColor, panelColor);

        drawClockBox(dc, textColor, panelColor);

        drawStepsBox(dc, textColor, panelColor);
        drawSolarBox(dc, textColor, panelColor);

        drawDateBox(dc, textColor, panelColor);
        drawWeatherBox(dc, textColor, panelColor);

        drawFooter(dc, textColor);
    }

    // Fixed 60x14 title box (was 112x18 in V2 - narrowed for bezel margin,
    // see the class-level comment above), day-mode only (pure decoration,
    // doesn't survive into Always-On). The banner asset is a fixed 220x52
    // canvas - far larger than the box - so it's contain-fit scaled down via
    // Dc.drawScaledBitmap (through HudDraw.drawBitmapScaledCentered)
    // rather than force-stretched, which would visibly distort the
    // wing/text artwork since the box's aspect ratio doesn't match the
    // source asset's.
    private function drawTitleBanner(dc as Graphics.Dc) as Void {
        var cx = TITLE_BOX_X + (TITLE_BOX_W / 2.0);
        var cy = TITLE_BOX_Y + (TITLE_BOX_H / 2.0);
        HudDraw.drawBitmapScaledCentered(dc, cx, cy, _bannerAh64e, BANNER_W, BANNER_H, TITLE_BOX_W, TITLE_BOX_H);
    }

    // Battery box is the one field whose color can dynamically swap to
    // Tactical Alert Red (see ColorScheme.batteryColor) - border, fill
    // rect, label, and value text all use battColor so a critical charge
    // reads unmistakably at a glance. The chrome outline+nub bitmap itself
    // stays baked-in green (no runtime bitmap tint API - same constraint
    // V1 had), so only the vector-drawn parts of the box actually turn
    // red; the assembled box still reads clearly as an alert.
    // Client polish pass: "PWR" text label removed - the battery icon
    // itself (chrome + proportional fill) now sits up where the label
    // used to be (BATT_BOX_Y+14 vs. the label's old +2, roughly the same
    // top region of the box) and serves as the visual label. The percent
    // value moves to its own centered row underneath (BATT_BOX_Y+34, near
    // the box's bottom), so icon and value read as two clearly separated
    // rows instead of a label+icon+value crowded into one.
    private function drawBatteryBox(dc as Graphics.Dc, battery as Float, battColor as Number) as Void {
        HudDraw.drawPanel(dc, BATT_BOX_X, BATT_BOX_Y, BATT_BOX_W, BATT_BOX_H, battColor);

        var iconCX = BATT_BOX_X + (BATT_BOX_W / 2.0);
        var iconCY = BATT_BOX_Y + 13.0; // client: "move the battery up 1 pixel" (was +14)
        var battChrome = _isSleeping ? _iconBatteryChromeAod : _iconBatteryChromeDay;
        HudDraw.drawBitmapCentered(dc, iconCX, iconCY, battChrome, BATTERY_W, BATTERY_H);
        HudDraw.drawBatteryFill(dc, iconCX - (BATTERY_W / 2.0), iconCY - (BATTERY_H / 2.0), BATTERY_W, BATTERY_H, battery, battColor);

        var valueCY = BATT_BOX_Y + 34.0;
        dc.setColor(battColor, Graphics.COLOR_TRANSPARENT);
        // client: "reduce the font of the battery number by 1" - dedicated
        // batteryValueFont(), scoped to just this field.
        dc.drawText(iconCX, valueCY, Fonts.batteryValueFont(), battery.format("%d") + "%",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Client: "HR" text label removed, heart icon lifted up to roughly
    // where the label used to sit - the same icon-on-top/value-below
    // structure the battery box already uses (this also resolves the
    // visual inconsistency flagged after that pass: both boxes now match).
    private function drawHeartRateBox(dc as Graphics.Dc, textColor as Number, panelColor as Number) as Void {
        HudDraw.drawPanel(dc, HR_BOX_X, HR_BOX_Y, HR_BOX_W, HR_BOX_H, panelColor);

        var iconCX = HR_BOX_X + (HR_BOX_W / 2.0);
        var iconCY = HR_BOX_Y + 14.0;
        var heartIcon = _isSleeping ? _iconHeartAod : _iconHeartDay;
        HudDraw.drawBitmapCentered(dc, iconCX, iconCY, heartIcon, HEART_W, HEART_H);

        var hr = _cache.heartRate;
        var hrText = (hr != null) ? hr.toString() : "--";
        var valueCY = HR_BOX_Y + 34.0;
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(iconCX, valueCY, Fonts.metricsFont(), hrText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawClockBox(dc as Graphics.Dc, textColor as Number, panelColor as Number) as Void {
        HudDraw.drawPanel(dc, CLOCK_BOX_X, CLOCK_BOX_Y, CLOCK_BOX_W, CLOCK_BOX_H, panelColor);

        var cx = CLOCK_BOX_X + (CLOCK_BOX_W / 2.0);
        var cy = CLOCK_BOX_Y + (CLOCK_BOX_H / 2.0);

        // Always 24-hour, regardless of device settings - client asked for
        // this explicitly, same as V1.
        var clockTime = System.getClockTime();
        var timeStr = Lang.format("$1$:$2$", [clockTime.hour.format("%02d"), clockTime.min.format("%02d")]);

        var timeFont = Fonts.timeFont();
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, timeFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (!_isSleeping) {
            var timeDims = dc.getTextDimensions(timeStr, timeFont);
            var secFont = Fonts.secondsFont();
            var secStr = clockTime.sec.format("%02d");
            var secDims = dc.getTextDimensions(secStr, secFont);

            var secX = cx + (timeDims[0] / 2.0) + 6.0;
            var maxSecX = CLOCK_BOX_X + CLOCK_BOX_W - 6.0 - secDims[0];
            if (secX > maxSecX) {
                secX = maxSecX;
            }

            dc.drawText(secX, cy + (timeDims[1] * 0.18), secFont, secStr,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function drawStepsBox(dc as Graphics.Dc, textColor as Number, panelColor as Number) as Void {
        HudDraw.drawPanel(dc, STEPS_BOX_X, STEPS_BOX_Y, STEPS_BOX_W, STEPS_BOX_H, panelColor);

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        // client: "move the STP over to be centered as well"
        dc.drawText(STEPS_BOX_X + (STEPS_BOX_W / 2.0), STEPS_BOX_Y + 2.0, Fonts.labelsFont(), "STP",
            Graphics.TEXT_JUSTIFY_CENTER);

        var contentY = STEPS_BOX_Y + (STEPS_BOX_H * 0.66);
        var bootIcon = _isSleeping ? _iconBootAod : _iconBootDay;
        var iconCX = STEPS_BOX_X + 10.0 + (BOOT_W / 2.0);
        HudDraw.drawBitmapCentered(dc, iconCX, contentY, bootIcon, BOOT_W, BOOT_H);

        var stepsText = "--";
        var info = ActivityMonitor.getInfo();
        if (info != null && info.steps != null) {
            stepsText = info.steps.toString();
        }

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(STEPS_BOX_X + STEPS_BOX_W - 8.0, contentY, Fonts.metricsFont(), stepsText,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawSolarBox(dc as Graphics.Dc, textColor as Number, panelColor as Number) as Void {
        HudDraw.drawPanel(dc, SOLAR_BOX_X, SOLAR_BOX_Y, SOLAR_BOX_W, SOLAR_BOX_H, panelColor);

        // "NEXT SOLAR" (10 chars) overflowed past the box's right border
        // once the box was narrowed for bezel margin (real screenshot
        // caught this, not just an estimate) - shortened to "SOLAR" to
        // match the terseness of every other box label (PWR/HR/STP), same
        // field, same icon (rise/set arrow) makes the meaning clear without
        // the word "NEXT".
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(SOLAR_BOX_X + 8.0, SOLAR_BOX_Y + 2.0, Fonts.labelsFont(), "SOLAR", Graphics.TEXT_JUSTIFY_LEFT);

        var contentY = SOLAR_BOX_Y + (SOLAR_BOX_H * 0.66);
        var label = "--:--";
        var isRise = true;
        var evLabel = _cache.solarEventLabel;
        var evMoment = _cache.solarEventMoment;
        if (evLabel != null && evMoment != null) {
            isRise = evLabel.equals("RISE");
            var info2 = Gregorian.info(evMoment, Time.FORMAT_SHORT);
            label = Lang.format("$1$:$2$", [info2.hour.format("%02d"), info2.min.format("%02d")]);
        }

        var solarIcon;
        if (_isSleeping) {
            solarIcon = isRise ? _iconSolarRiseAod : _iconSolarSetAod;
        } else {
            solarIcon = isRise ? _iconSolarRiseDay : _iconSolarSetDay;
        }

        var iconCX = SOLAR_BOX_X + 10.0 + (SOLAR_W / 2.0);
        HudDraw.drawBitmapCentered(dc, iconCX, contentY, solarIcon, SOLAR_W, SOLAR_H);

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(SOLAR_BOX_X + SOLAR_BOX_W - 8.0, contentY, Fonts.metricsFont(), label,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawDateBox(dc as Graphics.Dc, textColor as Number, panelColor as Number) as Void {
        HudDraw.drawPanel(dc, DATE_BOX_X, DATE_BOX_Y, DATE_BOX_W, DATE_BOX_H, panelColor);

        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dayName = DAY_ABBREV[info.day_of_week];
        var ddMm = Properties.getValue("dateFormatDDMM") as Number;
        var dateNums = (ddMm == 1)
            ? Lang.format("$1$/$2$", [info.day.format("%02d"), info.month.format("%02d")])
            : Lang.format("$1$/$2$", [info.month.format("%02d"), info.day.format("%02d")]);

        var cx = DATE_BOX_X + (DATE_BOX_W / 2.0);
        var cy = DATE_BOX_Y + (DATE_BOX_H / 2.0);

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Fonts.dateFont(), dayName + " " + dateNums, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Weather gets its own dedicated box in V2 (superseding V1's combined
    // WX+BT/notification row) - Bluetooth connection and the notification
    // bell now flank this box left/right instead, per the brief. The
    // native 32x32 weather icon and the 22x22/24x24 BT/bell icons are all
    // scaled down together to a common size so the whole status strip
    // reads as one consistent row rather than three mismatched icon
    // sizes.
    private function drawWeatherBox(dc as Graphics.Dc, textColor as Number, panelColor as Number) as Void {
        HudDraw.drawPanel(dc, WX_BOX_X, WX_BOX_Y, WX_BOX_W, WX_BOX_H, panelColor);

        var cy = WX_BOX_Y + (WX_BOX_H / 2.0);

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(WX_BOX_X + 6.0, cy, Fonts.labelsFont(), "WX", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var fullBucket = HudDraw.mapConditionToBucket(_cache.weatherCondition);
        var icon;
        if (_isSleeping) {
            // Always-On simplifies to 2 states per the brief: clear/cloudy
            // collapse to the plain clear glyph, everything else collapses
            // to the plain overcast glyph.
            icon = (fullBucket == :clear || fullBucket == :cloudy) ? _iconWxClearAod : _iconWxOvercastAod;
        } else if (fullBucket == :clear) {
            icon = _iconWxClearDay;
        } else if (fullBucket == :cloudy) {
            icon = _iconWxCloudyDay;
        } else if (fullBucket == :rain) {
            icon = _iconWxRainDay;
        } else if (fullBucket == :snow) {
            icon = _iconWxSnowDay;
        } else if (fullBucket == :storm) {
            icon = _iconWxStormDay;
        } else {
            icon = _iconWxOvercastDay;
        }

        var statusIconSize = WX_BOX_H - 2.0;
        var wxIconCX = WX_BOX_X + 22.0 + (statusIconSize / 2.0);
        HudDraw.drawBitmapScaledCentered(dc, wxIconCX, cy, icon, WX_W, WX_H, statusIconSize, statusIconSize);

        // Client polish pass: box grew 16->20px tall specifically to make
        // room for a bigger icon (statusIconSize above is WX_BOX_H-2, so
        // 14->18px automatically) and bigger temp text - now uses
        // FntMetrics (13px, the same size every other stat box's value
        // uses) instead of the old FntFooter (11px) fallback that only
        // existed because the box used to be too short for it.
        var tempText = formatTemperature(_cache.weatherTemperatureC);
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(WX_BOX_X + WX_BOX_W - 6.0, cy, Fonts.metricsFont(), tempText,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        drawStatusFlanking(dc, cy, textColor, panelColor);
    }

    // Bluetooth connection glyph (+ live connected/disconnected dot) on the
    // left of the Weather box, notification bell (+ live unread-count
    // badge, skipped when the count is 0) on the right - "within the
    // bottom status alignment" per the brief, positioned relative to the
    // Weather box's real (possibly-nudged) edges rather than the original
    // spec coordinates.
    //
    // This deep into the bottom of a round display there is limited
    // horizontal safe room left outside the Weather box itself (measured:
    // ~78px half-width available at this row vs. the box's own 40px
    // half-width, i.e. ~38px of slack per side after the V2.1 narrowing -
    // better than V2's ~14px) - these two icons stay deliberately tiny and
    // tucked close to the box edges rather than given the same breathing
    // room as the rest of the face's chrome. Noted explicitly in the
    // README rather than silently shrinking them without comment.
    private function drawStatusFlanking(dc as Graphics.Dc, cy as Float, textColor as Number, panelColor as Number) as Void {
        var deviceSettings = System.getDeviceSettings();
        var phoneConnected = deviceSettings.phoneConnected;
        var notifCount = deviceSettings.notificationCount;

        var btIcon = _isSleeping ? _iconBluetoothAod : _iconBluetoothDay;
        var bellIcon = _isSleeping ? _iconBellAod : _iconBellDay;
        var iconSize = 12.0;

        var btCX = WX_BOX_X - 1.0 - (iconSize / 2.0);
        HudDraw.drawBitmapScaledCentered(dc, btCX, cy, btIcon, BT_W, BT_H, iconSize, iconSize);

        // Connection-status dot is live state, not decoration - shown in
        // both modes: text color when the phone link is up, dim panel
        // color when it's down.
        var dotColor = phoneConnected ? textColor : panelColor;
        dc.setColor(dotColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(btCX + (iconSize * 0.30), cy - (iconSize * 0.30), 2.0);

        var bellCX = WX_BOX_X + WX_BOX_W + 1.0 + (iconSize / 2.0);
        HudDraw.drawBitmapScaledCentered(dc, bellCX, cy, bellIcon, BELL_W, BELL_H, iconSize, iconSize);

        if (notifCount > 0) {
            var countText = (notifCount > 9) ? "9+" : notifCount.toString();
            dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(bellCX + (iconSize / 2.0) + 3.0, cy, Fonts.labelsFont(), countText,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Small centered callsign banner with a short tactical flourish tick on
    // each side - kept in both modes (it's static chrome, same cost as the
    // panel borders, not a per-second animation).
    private function drawFooter(dc as Graphics.Dc, textColor as Number) as Void {
        var text = "BRAVO-4";
        var font = Fonts.footerFont();
        var dims = dc.getTextDimensions(text, font);
        var cy = FOOTER_Y + (FOOTER_H / 2.0);

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(FOOTER_CX, cy, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var flourishInner = (dims[0] / 2.0) + 6.0;
        var flourishOuter = flourishInner + 10.0;
        dc.setPenWidth(1);
        dc.drawLine(FOOTER_CX - flourishOuter, cy, FOOTER_CX - flourishInner, cy);
        dc.drawLine(FOOTER_CX + flourishInner, cy, FOOTER_CX + flourishOuter, cy);
    }

    private function formatTemperature(celsius as Numeric?) as String {
        if (celsius == null) {
            return "--°";
        }

        var useMetric = (System.getDeviceSettings().temperatureUnits == System.UNIT_METRIC);
        var value = useMetric ? celsius.toFloat() : (celsius.toFloat() * 9.0 / 5.0) + 32.0;
        return value.format("%.0f") + "°";
    }
}

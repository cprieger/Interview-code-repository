import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.ActivityMonitor;
import Toybox.Application.Properties;

// Fantasy Watchface V1 - "etched stone / glowing rune" parchment-map
// theme. Ports apache-watchface V6's layout methodology (fixed pixel
// matrix tuned for the real 280x280 fenix7xpro panel, corner-distance
// bezel verification against center (140,140)/r=140, day/AOD bitmap
// pairs, divider-based field separation) but is a fully separate app with
// its own theme - not a version of that app. See CLAUDE.md for the full
// derivation of the numbers below plus the two hard-won findings (128KB
// memory ceiling + declared-palette lesson, RGB222 4-level color grid)
// that constrain every color/bitmap choice on this face.
//
// Two structural differences from apache-watchface V6 drove this matrix:
//   1. No title banner at all (client: "remove the AH-64E") - the top
//      pole of the circle is empty of text now (just the background's
//      compass-rose motif). The Battery/HR row's V6 Y=33 was a 5px-down
//      nudge specifically to clear that title text; reverted here to
//      Y=27 (back near the pre-nudge V2.1 value) since there's no title
//      to clear - bezel geometry (not the title) turns out to be the
//      real ceiling on how far up this row can go: at this row's 70px
//      half-width, corner-distance math requires Y>=~26 for a 6px margin
//      regardless of title presence (see the constant's own comment).
//   2. A new Lore Text field sits directly under the clock (task 6) -
//      this is genuinely NEW vertical content, not just decoration
//      freed up by the title's removal, so fitting it required trimming
//      the Battery/HR row height and the Clock box height somewhat from
//      their V6 values, not just sliding existing rows up. Everything
//      from the Steps/Solar row down is UNCHANGED from V6's matrix
//      (same Y positions) - re-verified below, not just carried over
//      unchecked, but the numbers didn't need to move since the new
//      content was fully absorbed above them.
//
// Corner-distance formula used throughout, same as apache-watchface:
//   worst_corner_dist = sqrt(max(|left-cx|,|right-cx|)^2 + max(|top-cy|,|bottom-cy|)^2)
// against center (140,140), required < 140 with an established >=6px
// margin convention.
class FantasyWatchFaceView extends WatchUi.WatchFace {
    private const DAY_ABBREV as Array<String> = ["", "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];

    // ---- Native bitmap pixel dimensions ----
    private const BATTERY_W = 34.0;
    private const BATTERY_H = 18.0;
    private const HEART_W = 28.0;
    private const HEART_H = 27.0;
    private const BOOT_W = 36.0;
    private const BOOT_H = 32.0;
    private const SOLAR_W = 28.0;
    private const SOLAR_H = 28.0;
    private const SOLAR_DISPLAY_SIZE = 17.0;
    private const WX_W = 32.0;
    private const WX_H = 32.0;
    private const BT_W = 22.0;
    private const BT_H = 22.0;
    private const BELL_W = 24.0;
    private const BELL_H = 24.0;
    private const STATUS_ICON_SIZE = 14.0;
    private const STATUS_ICON_GAP = 2.0;

    // ---- pixel coordinate matrix ----

    // Battery/HR row. X-span (70..134 and 146..210) gives a 70px half-
    // width from center; at that half-width, corner-distance math requires
    // Y>=~25.7 for a 6px margin - Y=27 verified: dx=70, dy=|27-140|=113,
    // dist=sqrt(70^2+113^2)=132.9, margin=7.1px.
    private const BATT_BOX_X = 70.0;
    private const BATT_BOX_Y = 27.0;
    private const BATT_BOX_W = 64.0;
    private const BATT_BOX_H = 40.0;

    private const HR_BOX_X = 146.0;
    private const HR_BOX_Y = 27.0;
    private const HR_BOX_W = 64.0;
    // HR shares BATT_BOX_H (same row).

    private const DIV1_Y = 70.0;
    private const DIV1_X1 = 66.0;
    private const DIV1_X2 = 214.0;
    private const DIV_BATTHR_X = 140.0;
    private const DIV_BATTHR_Y1 = 30.0;
    private const DIV_BATTHR_Y2 = 64.0;

    // Clock: still the largest text on the face by a wide margin (34px
    // stone layer vs. the next-largest field, HR/steps/solar values, at
    // 13px) - "biggest, centered, highest contrast" per the design spec
    // holds even though the stone size is a bit below apache-watchface
    // V6's 44px, a deliberate, documented tradeoff for fitting the new
    // Lore Text field directly beneath it without touching the
    // Steps/Solar row's position. Margin: dx=112, dy=max(|74-140|,|131-140|)=66,
    // dist=sqrt(112^2+66^2)=130.0, margin=10.0px.
    private const CLOCK_BOX_X = 28.0;
    private const CLOCK_BOX_Y = 74.0;
    private const CLOCK_BOX_W = 224.0;
    private const CLOCK_BOX_H = 57.0;

    // Lore Text: directly under the clock (task 6). Same X/W as the clock
    // box for visual alignment. Margin: dx=112, dy=max(|135-140|,|163-140|)=23,
    // dist=sqrt(112^2+23^2)=114.3, margin=25.7px (this row sits close to
    // true vertical center, plenty of headroom).
    private const LORE_BOX_X = 28.0;
    private const LORE_BOX_Y = 135.0;
    private const LORE_BOX_W = 224.0;
    private const LORE_BOX_H = 32.0;
    private const LORE_MAX_LINES = 3;

    private const DIV2_Y = 167.0;
    private const DIV2_X1 = 40.0;
    private const DIV2_X2 = 240.0;

    // Everything from here down is UNCHANGED from apache-watchface V6's
    // matrix (re-verified against the same corner-distance formula, not
    // just carried over blind - numbers are identical because the new
    // Lore Text field was fully absorbed above, in the Battery/HR/Clock
    // section, so nothing below DIV2 needed to move).
    private const STEPS_BOX_X = 36.0;
    private const STEPS_BOX_Y = 171.0;
    private const STEPS_BOX_W = 114.0;
    private const STEPS_BOX_H = 44.0;

    private const SOLAR_BOX_X = 156.0;
    private const SOLAR_BOX_Y = 171.0;
    private const SOLAR_BOX_W = 88.0;
    private const SOLAR_BOX_H = 44.0;

    private const DIV_STEPSSOLAR_X = 153.0;
    private const DIV_STEPSSOLAR_Y1 = 175.0;
    private const DIV_STEPSSOLAR_Y2 = 211.0;
    private const DIV3_Y = 218.0;
    private const DIV3_X1 = 36.0;
    private const DIV3_X2 = 244.0;

    // Date + Timezone2 share one row, split by a vertical wall divider.
    // Margin (tightest in this matrix, same as V6): dx=84, dy=max(|222-140|,|242-140|)=102,
    // dist=sqrt(84^2+102^2)=132.1, margin=7.9px.
    private const DATE_BOX_X = 56.0;
    private const DATE_BOX_Y = 222.0;
    private const DATE_BOX_W = 80.0;
    private const DATE_BOX_H = 20.0;

    private const TZ2_BOX_X = 144.0;
    private const TZ2_BOX_Y = 222.0;
    private const TZ2_BOX_W = 80.0;
    private const TZ2_BOX_H = 20.0;

    private const DIV_DATETZ2_X = 140.0;
    private const DIV_DATETZ2_Y1 = 224.0;
    private const DIV_DATETZ2_Y2 = 240.0;
    private const DIV4_Y = 244.0;
    private const DIV4_X1 = 60.0;
    private const DIV4_X2 = 220.0;

    // Margin: dx=44, dy=max(|246-140|,|264-140|)=124, dist=sqrt(44^2+124^2)=131.6,
    // margin=8.4px.
    private const WX_BOX_X = 96.0;
    private const WX_BOX_Y = 246.0;
    private const WX_BOX_W = 88.0;
    private const WX_BOX_H = 18.0;

    // Footer position UNCHANGED from apache-watchface - this Y was
    // already real-screenshot-verified as the safe floor near the bottom
    // pole (the round display's edge curvature softens content in the
    // last ~15px of radius regardless of what corner-distance math alone
    // says). No reason to gamble that margin here.
    private const FOOTER_CX = 140.0;
    private const FOOTER_Y = 266.0;
    private const FOOTER_H = 8.0;
    private const FOOTER_MAX_HALF_W = 42.0;

    private var _cache as DataCache;
    private var _isSleeping as Boolean = false;
    private var _iconsLoaded as Boolean = false;
    private var _loreIndex as Number = 0;

    private var _bgMap as Graphics.BitmapType?;
    private var _iconPotionDay as Graphics.BitmapType?;
    private var _iconPotionAod as Graphics.BitmapType?;
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
    private var _iconBluetoothDay as Graphics.BitmapType?;
    private var _iconBluetoothAod as Graphics.BitmapType?;
    private var _iconBellDay as Graphics.BitmapType?;
    private var _iconBellAod as Graphics.BitmapType?;
    private var _wallHDay as Graphics.BitmapType?;
    private var _wallHAod as Graphics.BitmapType?;
    private var _wallVDay as Graphics.BitmapType?;
    private var _wallVAod as Graphics.BitmapType?;

    function initialize() {
        WatchFace.initialize();
        _cache = new DataCache();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        loadIcons();
        // Cold-start lore index - onExitSleep() won't have fired yet for
        // the very first render, so this guarantees something other than
        // index 0-by-default-var shows on first paint too.
        _loreIndex = pickLoreIndex();
    }

    private function loadIcons() as Void {
        if (_iconsLoaded) {
            return;
        }

        _bgMap = WatchUi.loadResource(Rez.Drawables.BackgroundMap) as Graphics.BitmapType;

        _iconPotionDay = WatchUi.loadResource(Rez.Drawables.IconPotionGlassDay) as Graphics.BitmapType;
        _iconPotionAod = WatchUi.loadResource(Rez.Drawables.IconPotionGlassAod) as Graphics.BitmapType;

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

        _iconBluetoothDay = WatchUi.loadResource(Rez.Drawables.IconBluetoothDay) as Graphics.BitmapType;
        _iconBluetoothAod = WatchUi.loadResource(Rez.Drawables.IconBluetoothAod) as Graphics.BitmapType;
        _iconBellDay = WatchUi.loadResource(Rez.Drawables.IconBellDay) as Graphics.BitmapType;
        _iconBellAod = WatchUi.loadResource(Rez.Drawables.IconBellAod) as Graphics.BitmapType;

        _wallHDay = WatchUi.loadResource(Rez.Drawables.WallHDay) as Graphics.BitmapType;
        _wallHAod = WatchUi.loadResource(Rez.Drawables.WallHAod) as Graphics.BitmapType;
        _wallVDay = WatchUi.loadResource(Rez.Drawables.WallVDay) as Graphics.BitmapType;
        _wallVAod = WatchUi.loadResource(Rez.Drawables.WallVAod) as Graphics.BitmapType;

        _iconsLoaded = true;
    }

    function onShow() as Void {
    }

    function onHide() as Void {
    }

    // The ONLY point the Lore Text index is allowed to change - fires
    // exactly on the sleep->active wake transition. onUpdate() only ever
    // renders whatever _loreIndex already holds; it never recomputes it,
    // even if steps changed while already awake (see pickLoreIndex()).
    function onExitSleep() as Void {
        _isSleeping = false;
        _loreIndex = pickLoreIndex();
    }

    function onEnterSleep() as Void {
        _isSleeping = true;
        WatchUi.requestUpdate();
    }

    // No onPartialUpdate() override, same reasoning as apache-watchface:
    // seconds (the one per-second element) are hidden in Always-On mode,
    // so the system's default once-a-minute onUpdate() fallback while
    // asleep is exactly right, for free.
    function onUpdate(dc as Graphics.Dc) as Void {
        _cache.refresh(_isSleeping);

        if (_isSleeping) {
            // AOD simplifies to plain black - no reason to redraw a static
            // bitmap background on a MIP display that gains nothing power-
            // wise from it, and the "sleep state" contrast reads better.
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.clear();
        } else if (_bgMap != null) {
            // Background bitmap already covers the full 280x280 canvas -
            // no dc.clear() needed/wanted first.
            dc.drawBitmap(0, 0, _bgMap);
        } else {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.clear();
        }

        var stoneColor = ColorScheme.stoneColor(_isSleeping);
        var runeColor = ColorScheme.runeColor(_isSleeping);
        var wallH = _isSleeping ? _wallHAod : _wallHDay;
        var wallV = _isSleeping ? _wallVAod : _wallVDay;

        var battery = System.getSystemStats().battery;
        drawBatteryBox(dc, battery);
        drawHeartRateBox(dc, stoneColor, runeColor);
        drawStatusFlanking(dc, stoneColor);

        HudDraw.drawWallH(dc, DIV1_X1, DIV1_X2, DIV1_Y, wallH);
        HudDraw.drawWallV(dc, DIV_BATTHR_X, DIV_BATTHR_Y1, DIV_BATTHR_Y2, wallV);

        drawClockBox(dc, stoneColor, runeColor);
        drawLoreBox(dc, stoneColor, runeColor);

        HudDraw.drawWallH(dc, DIV2_X1, DIV2_X2, DIV2_Y, wallH);

        drawStepsBox(dc, stoneColor, runeColor);
        drawSolarBox(dc, stoneColor, runeColor);
        HudDraw.drawWallV(dc, DIV_STEPSSOLAR_X, DIV_STEPSSOLAR_Y1, DIV_STEPSSOLAR_Y2, wallV);
        HudDraw.drawWallH(dc, DIV3_X1, DIV3_X2, DIV3_Y, wallH);

        drawDateBox(dc, stoneColor, runeColor);
        drawTz2Box(dc, stoneColor, runeColor);
        HudDraw.drawWallV(dc, DIV_DATETZ2_X, DIV_DATETZ2_Y1, DIV_DATETZ2_Y2, wallV);
        HudDraw.drawWallH(dc, DIV4_X1, DIV4_X2, DIV4_Y, wallH);

        drawWeatherBox(dc, stoneColor, runeColor);

        drawFooter(dc, stoneColor, runeColor);
    }

    // ---- Lore Text selection (task 6) ----

    private function digitSum(n as Number) as Number {
        var sum = 0;
        var v = (n < 0) ? -n : n;
        while (v > 0) {
            sum += v % 10;
            v = v / 10;
        }
        return sum;
    }

    private function pickLoreIndex() as Number {
        var steps = 0;
        var info = ActivityMonitor.getInfo();
        if (info != null && info.steps != null) {
            steps = info.steps;
        }
        return digitSum(steps) % LoreText.ENTRIES.size();
    }

    // ---- draw*Box methods ----

    private function drawBatteryBox(dc as Graphics.Dc, battery as Float) as Void {
        var iconCX = BATT_BOX_X + (BATT_BOX_W / 2.0);
        var iconCY = BATT_BOX_Y + 12.0;
        var potionIcon = _isSleeping ? _iconPotionAod : _iconPotionDay;
        HudDraw.drawBitmapCentered(dc, iconCX, iconCY, potionIcon, BATTERY_W, BATTERY_H);

        var fillColor = ColorScheme.manaFillColor(_isSleeping, battery);
        HudDraw.drawPotionFill(dc, iconCX - (BATTERY_W / 2.0), iconCY - (BATTERY_H / 2.0), BATTERY_W, BATTERY_H, battery, fillColor);

        var stoneColor = ColorScheme.batteryStoneColor(_isSleeping, battery);
        var runeColor = ColorScheme.batteryRuneColor(_isSleeping, battery);
        var valueCY = BATT_BOX_Y + 31.0;
        var battValueText = battery.format("%d") + "%";
        ThemeText.drawDual(dc, iconCX, valueCY, battValueText, Fonts.batteryValueFont(), Fonts.batteryValueFontRune(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER, stoneColor, runeColor);
    }

    private function drawHeartRateBox(dc as Graphics.Dc, stoneColor as Number, runeColor as Number) as Void {
        var iconCX = HR_BOX_X + (HR_BOX_W / 2.0);
        var iconCY = HR_BOX_Y + 13.0;
        var heartIcon = _isSleeping ? _iconHeartAod : _iconHeartDay;
        HudDraw.drawBitmapCentered(dc, iconCX, iconCY, heartIcon, HEART_W, HEART_H);

        var hr = _cache.heartRate;
        var hrText = (hr != null) ? hr.toString() : "--";
        var valueCY = HR_BOX_Y + 31.0;
        ThemeText.drawDual(dc, iconCX, valueCY, hrText, Fonts.metricsFont(), Fonts.metricsFontRune(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER, stoneColor, runeColor);
    }

    private const TIME_ANCHOR_SHIFT_PX = 5.0;

    private function drawClockBox(dc as Graphics.Dc, stoneColor as Number, runeColor as Number) as Void {
        var boxCX = CLOCK_BOX_X + (CLOCK_BOX_W / 2.0);
        var cy = CLOCK_BOX_Y + (CLOCK_BOX_H / 2.0);
        var timeCX = boxCX - TIME_ANCHOR_SHIFT_PX;

        // Always 24-hour, same convention as apache-watchface.
        var clockTime = System.getClockTime();
        var timeStr = Lang.format("$1$:$2$", [clockTime.hour.format("%02d"), clockTime.min.format("%02d")]);

        var stoneFont = Fonts.timeFont();
        var runeFont = Fonts.timeFontRune();
        ThemeText.drawDual(dc, timeCX, cy, timeStr, stoneFont, runeFont,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER, stoneColor, runeColor);

        if (!_isSleeping) {
            var timeDims = dc.getTextDimensions(timeStr, stoneFont);
            var secStoneFont = Fonts.secondsFont();
            var secRuneFont = Fonts.secondsFontRune();
            var secStr = clockTime.sec.format("%02d");
            var secDims = dc.getTextDimensions(secStr, secStoneFont);

            var secX = boxCX + (timeDims[0] / 2.0) + 6.0;
            var maxSecX = CLOCK_BOX_X + CLOCK_BOX_W - 6.0 - secDims[0];
            if (secX > maxSecX) {
                secX = maxSecX;
            }

            ThemeText.drawDual(dc, secX, cy + (timeDims[1] * 0.18), secStr, secStoneFont, secRuneFont,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER, stoneColor, runeColor);
        }
    }

    // Word-wraps `text` to fit within `maxWidth`, capped at `maxLines`
    // lines - real per-candidate-line pixel measurement via
    // dc.getTextDimensions(), same pattern apache-watchface uses for its
    // own overflow checks, not a character-count estimate. If the text
    // doesn't fit even at maxLines, the last line is truncated with "..."
    // (trimmed character-by-character until the ellipsis-suffixed line
    // measures inside maxWidth) rather than overflowing the bezel.
    private function wrapLoreText(dc as Graphics.Dc, text as String, font as Graphics.FontType, maxWidth as Float, maxLines as Number) as Array<String> {
        var words = splitWords(text);
        var lines = [] as Array<String>;
        var current = "";
        var i = 0;
        var n = words.size();

        while (i < n && lines.size() < maxLines) {
            var w = words[i];
            var candidate = (current.length() == 0) ? w : (current + " " + w);
            var dims = dc.getTextDimensions(candidate, font);
            if (dims[0] <= maxWidth || current.length() == 0) {
                // Always accept at least one word per line, even an
                // over-wide single word, to guarantee forward progress.
                current = candidate;
                i += 1;
            } else {
                lines.add(current);
                current = "";
            }
        }
        if (current.length() > 0 && lines.size() < maxLines) {
            lines.add(current);
            current = "";
        }

        var overflow = (i < n) || (current.length() > 0);
        if (overflow && lines.size() > 0) {
            var lastIdx = lines.size() - 1;
            var last = lines[lastIdx];
            var withEllipsis = last + "...";
            while (dc.getTextDimensions(withEllipsis, font)[0] > maxWidth && last.length() > 0) {
                last = last.substring(0, last.length() - 1);
                withEllipsis = last + "...";
            }
            lines[lastIdx] = withEllipsis;
        }

        return lines;
    }

    // Monkey C's Lang.String has no split() method in this SDK - splits
    // on single spaces manually via find()/substring().
    private function splitWords(text as String) as Array<String> {
        var words = [] as Array<String>;
        var remaining = text;
        while (true) {
            var idx = remaining.find(" ");
            if (idx == null) {
                if (remaining.length() > 0) {
                    words.add(remaining);
                }
                break;
            }
            var word = remaining.substring(0, idx);
            if (word.length() > 0) {
                words.add(word);
            }
            remaining = remaining.substring(idx + 1, remaining.length());
        }
        return words;
    }

    // Real-device finding (see CLAUDE.md): Dc.getTextDimensions()'s
    // reported HEIGHT for this device's small vector-font requests (tested
    // 5-24px) is unreliable for line-spacing math - it clustered at a flat
    // ~19px regardless of the requested size, which is not what the glyphs
    // actually render at (confirmed by a zoomed screenshot: stacking 3
    // lines at that reported pitch spilled ~30px past the Lore box into
    // the divider and Steps/Solar row below it). WIDTH measurements are
    // trustworthy (used for word-wrap above) - only HEIGHT is affected.
    // Fix: use a fixed, screenshot-verified line pitch instead of trusting
    // the reported height.
    private const LORE_LINE_PITCH = 10.0;

    private function drawLoreBox(dc as Graphics.Dc, stoneColor as Number, runeColor as Number) as Void {
        var text = LoreText.get(_loreIndex);
        var stoneFont = Fonts.loreFont();
        var runeFont = Fonts.loreFontRune();
        var maxWidth = LORE_BOX_W - 8.0;
        var lines = wrapLoreText(dc, text, stoneFont, maxWidth, LORE_MAX_LINES);

        var lineH = LORE_LINE_PITCH;
        var totalH = lineH * lines.size();
        var cx = LORE_BOX_X + (LORE_BOX_W / 2.0);
        var startY = LORE_BOX_Y + ((LORE_BOX_H - totalH) / 2.0) + (lineH / 2.0);
        if (totalH > LORE_BOX_H) {
            // Defensive: if content is taller than the box's nominal
            // budget, anchor at the box top instead of vertically
            // centering rather than silently overflowing upward past the
            // divider above.
            startY = LORE_BOX_Y + (lineH / 2.0);
        }

        for (var i = 0; i < lines.size(); i++) {
            var y = startY + (i * lineH);
            ThemeText.drawDual(dc, cx, y, lines[i], stoneFont, runeFont,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER, stoneColor, runeColor);
        }
    }

    private function drawStepsBox(dc as Graphics.Dc, stoneColor as Number, runeColor as Number) as Void {
        ThemeText.drawDual(dc, STEPS_BOX_X + (STEPS_BOX_W / 2.0), STEPS_BOX_Y + 2.0, "STP",
            Fonts.labelsFont(), Fonts.labelsFontRune(), Graphics.TEXT_JUSTIFY_CENTER, stoneColor, runeColor);

        var contentY = STEPS_BOX_Y + (STEPS_BOX_H * 0.66);
        var bootIcon = _isSleeping ? _iconBootAod : _iconBootDay;
        var iconCX = STEPS_BOX_X + 10.0 + (BOOT_W / 2.0);
        HudDraw.drawBitmapCentered(dc, iconCX, contentY, bootIcon, BOOT_W, BOOT_H);

        var stepsText = "--";
        var info = ActivityMonitor.getInfo();
        if (info != null && info.steps != null) {
            stepsText = info.steps.toString();
        }

        ThemeText.drawDual(dc, STEPS_BOX_X + STEPS_BOX_W - 8.0, contentY, stepsText,
            Fonts.metricsFont(), Fonts.metricsFontRune(),
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER, stoneColor, runeColor);
    }

    private function drawSolarBox(dc as Graphics.Dc, stoneColor as Number, runeColor as Number) as Void {
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

        var boxLabel = isRise ? "SUNRISE" : "SUNSET";
        ThemeText.drawDual(dc, SOLAR_BOX_X + 8.0, SOLAR_BOX_Y + 2.0, boxLabel,
            Fonts.labelsFont(), Fonts.labelsFontRune(), Graphics.TEXT_JUSTIFY_LEFT, stoneColor, runeColor);

        var solarIcon;
        if (_isSleeping) {
            solarIcon = isRise ? _iconSolarRiseAod : _iconSolarSetAod;
        } else {
            solarIcon = isRise ? _iconSolarRiseDay : _iconSolarSetDay;
        }

        var iconCX = SOLAR_BOX_X + 6.0 + (SOLAR_DISPLAY_SIZE / 2.0);
        HudDraw.drawBitmapScaledCentered(dc, iconCX, contentY, solarIcon, SOLAR_W, SOLAR_H,
            SOLAR_DISPLAY_SIZE, SOLAR_DISPLAY_SIZE);

        ThemeText.drawDual(dc, SOLAR_BOX_X + SOLAR_BOX_W - 8.0, contentY, label,
            Fonts.metricsFont(), Fonts.metricsFontRune(),
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER, stoneColor, runeColor);
    }

    private function drawDateBox(dc as Graphics.Dc, stoneColor as Number, runeColor as Number) as Void {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dayName = DAY_ABBREV[info.day_of_week];
        var ddMm = Properties.getValue("dateFormatDDMM") as Number;
        var dateNums = (ddMm == 1)
            ? Lang.format("$1$/$2$", [info.day.format("%02d"), info.month.format("%02d")])
            : Lang.format("$1$/$2$", [info.month.format("%02d"), info.day.format("%02d")]);

        var cx = DATE_BOX_X + (DATE_BOX_W / 2.0);
        var cy = DATE_BOX_Y + (DATE_BOX_H / 2.0);

        ThemeText.drawDual(dc, cx, cy, dayName + " " + dateNums, Fonts.dateFont(), Fonts.dateFontRune(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER, stoneColor, runeColor);
    }

    private function drawTz2Box(dc as Graphics.Dc, stoneColor as Number, runeColor as Number) as Void {
        var zoneId = Properties.getValue("timezone2") as Number?;
        if (zoneId == null) {
            zoneId = TzCalc.ZONE_PACIFIC;
        }

        var hourMinute = TzCalc.currentHourMinute(zoneId);
        var timeStr = Lang.format("$1$:$2$", [hourMinute[0].format("%02d"), hourMinute[1].format("%02d")]);
        var label = TzCalc.zoneLabel(zoneId);

        var cx = TZ2_BOX_X + (TZ2_BOX_W / 2.0);
        var cy = TZ2_BOX_Y + (TZ2_BOX_H / 2.0);

        ThemeText.drawDual(dc, cx, cy, timeStr + " " + label, Fonts.dateFont(), Fonts.dateFontRune(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER, stoneColor, runeColor);
    }

    private function drawWeatherBox(dc as Graphics.Dc, stoneColor as Number, runeColor as Number) as Void {
        var cy = WX_BOX_Y + (WX_BOX_H / 2.0);

        var fullBucket = HudDraw.mapConditionToBucket(_cache.weatherCondition);
        var icon;
        if (_isSleeping) {
            // Always-On simplifies to 2 states: clear/cloudy collapse to
            // the plain clear glyph, everything else collapses to the
            // plain overcast glyph.
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
        var wxIconCX = WX_BOX_X + 8.0 + (statusIconSize / 2.0);
        HudDraw.drawBitmapScaledCentered(dc, wxIconCX, cy, icon, WX_W, WX_H, statusIconSize, statusIconSize);

        var tempText = formatTemperature(_cache.weatherTemperatureC);
        ThemeText.drawDual(dc, WX_BOX_X + WX_BOX_W - 6.0, cy, tempText, Fonts.tempValueFont(), Fonts.tempValueFontRune(),
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER, stoneColor, runeColor);
    }

    // Bluetooth connection glyph (+ live connected/disconnected dot) and
    // notification bell (+ live unread-count badge, skipped at 0) flank
    // the Battery/HR row, same position convention as apache-watchface.
    // The notif-count badge is intentionally single-color (stoneColor),
    // not dual-layer - it's a tiny transient status number, not one of
    // the seven spec fields, and dual-layering it at this size read as
    // muddy rather than legible.
    private function drawStatusFlanking(dc as Graphics.Dc, stoneColor as Number) as Void {
        var deviceSettings = System.getDeviceSettings();
        var phoneConnected = deviceSettings.phoneConnected;
        var notifCount = deviceSettings.notificationCount;

        var btIcon = _isSleeping ? _iconBluetoothAod : _iconBluetoothDay;
        var bellIcon = _isSleeping ? _iconBellAod : _iconBellDay;
        var iconSize = STATUS_ICON_SIZE;
        var cy = BATT_BOX_Y + (BATT_BOX_H * 0.66);

        var btCX = BATT_BOX_X - STATUS_ICON_GAP - (iconSize / 2.0);
        HudDraw.drawBitmapScaledCentered(dc, btCX, cy, btIcon, BT_W, BT_H, iconSize, iconSize);

        var dotColor = phoneConnected ? ColorScheme.runeColor(_isSleeping) : ColorScheme.dimColor(_isSleeping);
        dc.setColor(dotColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(btCX + (iconSize * 0.30), cy - (iconSize * 0.30), 2.0);

        var bellCX = HR_BOX_X + HR_BOX_W + STATUS_ICON_GAP + (iconSize / 2.0);
        HudDraw.drawBitmapScaledCentered(dc, bellCX, cy, bellIcon, BELL_W, BELL_H, iconSize, iconSize);

        if (notifCount > 0) {
            var countText = (notifCount > 9) ? "9+" : notifCount.toString();
            dc.setColor(stoneColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(bellCX + (iconSize / 2.0) + 3.0, cy, Fonts.labelsFont(), countText,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function drawFooter(dc as Graphics.Dc, stoneColor as Number, runeColor as Number) as Void {
        var text = Properties.getValue("squad") as String?;
        if (text == null || text.length() == 0) {
            text = "BRAVO-4";
        }
        if (text.length() > 8) {
            text = text.substring(0, 8);
        }

        var stoneFont = Fonts.footerFont();
        var runeFont = Fonts.footerFontRune();
        var dims = dc.getTextDimensions(text, stoneFont);
        var cy = FOOTER_Y + (FOOTER_H / 2.0);

        ThemeText.drawDual(dc, FOOTER_CX, cy, text, stoneFont, runeFont,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER, stoneColor, runeColor);

        var flourishInner = (dims[0] / 2.0) + 6.0;
        var flourishOuter = flourishInner + 10.0;
        if (flourishOuter > FOOTER_MAX_HALF_W) {
            flourishOuter = FOOTER_MAX_HALF_W;
        }
        dc.setColor(stoneColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        if (flourishOuter > flourishInner) {
            dc.drawLine(FOOTER_CX - flourishOuter, cy, FOOTER_CX - flourishInner, cy);
            dc.drawLine(FOOTER_CX + flourishInner, cy, FOOTER_CX + flourishOuter, cy);
        }
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

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
// per-field boxes. Every box below is (X, Y, W, H) as given in the V2
// spec table; two of them (Date, Weather) needed a small nudge after a
// real screenshot showed bezel clipping - see the comments on those two
// specifically. Nothing else was touched.
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
    private const BOOT_H = 24.0;
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

    // ---- V2 fixed pixel coordinate matrix (client spec, 280x280) ----
    private const TITLE_BOX_X = 84.0;
    private const TITLE_BOX_Y = 12.0;
    private const TITLE_BOX_W = 112.0;
    private const TITLE_BOX_H = 18.0;

    private const BATT_BOX_X = 20.0;
    private const BATT_BOX_Y = 32.0;
    private const BATT_BOX_W = 92.0;
    private const BATT_BOX_H = 46.0;

    private const HR_BOX_X = 168.0;
    private const HR_BOX_Y = 32.0;
    private const HR_BOX_W = 92.0;
    private const HR_BOX_H = 46.0;

    private const CLOCK_BOX_X = 22.0;
    private const CLOCK_BOX_Y = 84.0;
    private const CLOCK_BOX_W = 236.0;
    private const CLOCK_BOX_H = 72.0;

    private const STEPS_BOX_X = 20.0;
    private const STEPS_BOX_Y = 166.0;
    private const STEPS_BOX_W = 108.0;
    private const STEPS_BOX_H = 46.0;

    private const SOLAR_BOX_X = 152.0;
    private const SOLAR_BOX_Y = 166.0;
    private const SOLAR_BOX_W = 108.0;
    private const SOLAR_BOX_H = 46.0;

    // Date box: literal spec matrix values (X=34,Y=216,W=212,H=34).
    // Screenshotted and measured pixel-for-pixel (see README "Bezel
    // clipping check") - the date text itself renders comfortably inside
    // this box with margin to spare, so it's kept exactly as spec'd.
    private const DATE_BOX_X = 34.0;
    private const DATE_BOX_Y = 216.0;
    private const DATE_BOX_W = 212.0;
    private const DATE_BOX_H = 34.0;

    // Weather box: spec literal was X=54,Y=252,W=172,H=24. Two real,
    // independently-confirmed problems found from a screenshot + pixel
    // measurement of the first pass (see README):
    //   1. Bezel clipping - literal box corners land ~161px from center
    //      against a 140px bezel radius, worst of any box in the matrix.
    //   2. The client's own matrix has Footer starting at Y=268, which is
    //      BEFORE this box's own literal bottom edge (252+24=276) - the
    //      two elements were specified to overlap regardless of the round
    //      bezel. Screenshot confirmed this: weather temp/icon and the
    //      "BRAVO-4" footer text visibly overlapped.
    // Narrowed and nudged per the brief's explicit "nudge up/narrower
    // slightly" permission; BT/bell status icons (drawn in
    // drawStatusFlanking) key off these final numbers, not the original
    // spec ones.
    private const WX_BOX_X = 80.0;
    private const WX_BOX_Y = 250.0;
    private const WX_BOX_W = 120.0;
    private const WX_BOX_H = 18.0;

    // Footer: spec literal Y=268 overlapped the Weather box's own literal
    // bottom edge (276) even before considering the bezel - moved down to
    // start just after the (also-adjusted) Weather box's real bottom edge
    // instead, so the two no longer collide.
    private const FOOTER_CX = 140.0;
    private const FOOTER_Y = 270.0;
    private const FOOTER_H = 10.0;

    private const SCREEN_CX = 140.0;
    private const SCREEN_CY = 140.0;

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
    // for free. The V2 chapter-ring/box restyle doesn't change this.
    function onUpdate(dc as Graphics.Dc) as Void {
        _cache.refresh(_isSleeping);

        dc.setColor(Graphics.COLOR_WHITE, ColorScheme.BACKGROUND);
        dc.clear();

        var textColor = ColorScheme.textColor(_isSleeping);
        var panelColor = ColorScheme.panelColor(_isSleeping);

        // Chapter ring first (background layer) - every box below draws
        // on top of it.
        HudDraw.drawChapterRing(dc, SCREEN_CX, SCREEN_CY, textColor, panelColor);

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

    // Fixed 112x18 title box, day-mode only (pure decoration, doesn't
    // survive into Always-On). The banner asset is a fixed 220x52 canvas -
    // far larger than the box - so it's contain-fit scaled down via
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
    private function drawBatteryBox(dc as Graphics.Dc, battery as Float, battColor as Number) as Void {
        HudDraw.drawPanel(dc, BATT_BOX_X, BATT_BOX_Y, BATT_BOX_W, BATT_BOX_H, battColor);

        dc.setColor(battColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(BATT_BOX_X + 8.0, BATT_BOX_Y + 2.0, Fonts.labelsFont(), "PWR", Graphics.TEXT_JUSTIFY_LEFT);

        var contentY = BATT_BOX_Y + (BATT_BOX_H * 0.66);
        var battChrome = _isSleeping ? _iconBatteryChromeAod : _iconBatteryChromeDay;
        var iconCX = BATT_BOX_X + 10.0 + (BATTERY_W / 2.0);
        HudDraw.drawBitmapCentered(dc, iconCX, contentY, battChrome, BATTERY_W, BATTERY_H);
        HudDraw.drawBatteryFill(dc, iconCX - (BATTERY_W / 2.0), contentY - (BATTERY_H / 2.0), BATTERY_W, BATTERY_H, battery, battColor);

        dc.setColor(battColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(BATT_BOX_X + BATT_BOX_W - 8.0, contentY, Fonts.metricsFont(), battery.format("%d") + "%",
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        HudDraw.drawDashedLine(dc, BATT_BOX_X + 6.0, BATT_BOX_X + BATT_BOX_W - 6.0, BATT_BOX_Y + 16.0, battColor);
    }

    private function drawHeartRateBox(dc as Graphics.Dc, textColor as Number, panelColor as Number) as Void {
        HudDraw.drawPanel(dc, HR_BOX_X, HR_BOX_Y, HR_BOX_W, HR_BOX_H, panelColor);

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(HR_BOX_X + 8.0, HR_BOX_Y + 2.0, Fonts.labelsFont(), "HR", Graphics.TEXT_JUSTIFY_LEFT);

        var contentY = HR_BOX_Y + (HR_BOX_H * 0.66);
        var heartIcon = _isSleeping ? _iconHeartAod : _iconHeartDay;
        var iconCX = HR_BOX_X + 10.0 + (HEART_W / 2.0);
        HudDraw.drawBitmapCentered(dc, iconCX, contentY, heartIcon, HEART_W, HEART_H);

        var hr = _cache.heartRate;
        var hrText = (hr != null) ? hr.toString() : "--";
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(HR_BOX_X + HR_BOX_W - 8.0, contentY, Fonts.metricsFont(), hrText,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        HudDraw.drawDashedLine(dc, HR_BOX_X + 6.0, HR_BOX_X + HR_BOX_W - 6.0, HR_BOX_Y + 16.0, panelColor);
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
        dc.drawText(STEPS_BOX_X + 8.0, STEPS_BOX_Y + 2.0, Fonts.labelsFont(), "STP", Graphics.TEXT_JUSTIFY_LEFT);

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

        HudDraw.drawDashedLine(dc, STEPS_BOX_X + 6.0, STEPS_BOX_X + STEPS_BOX_W - 6.0, STEPS_BOX_Y + 16.0, panelColor);
    }

    private function drawSolarBox(dc as Graphics.Dc, textColor as Number, panelColor as Number) as Void {
        HudDraw.drawPanel(dc, SOLAR_BOX_X, SOLAR_BOX_Y, SOLAR_BOX_W, SOLAR_BOX_H, panelColor);

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(SOLAR_BOX_X + 8.0, SOLAR_BOX_Y + 2.0, Fonts.labelsFont(), "NEXT SOLAR", Graphics.TEXT_JUSTIFY_LEFT);

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

        HudDraw.drawDashedLine(dc, SOLAR_BOX_X + 6.0, SOLAR_BOX_X + SOLAR_BOX_W - 6.0, SOLAR_BOX_Y + 16.0, panelColor);
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

        // This box is by far the shortest in the matrix (18px, after the
        // clipping/overlap fix above) - FntMetrics (20px nominal, used by
        // every other stat box) rendered noticeably taller than this box
        // has room for, so the temperature value uses FntFooter (16px)
        // here instead, the next size down.
        var tempText = formatTemperature(_cache.weatherTemperatureC);
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(WX_BOX_X + WX_BOX_W - 6.0, cy, Fonts.footerFont(), tempText,
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
    // This deep into the bottom of a round display there is very little
    // horizontal safe room left outside the Weather box itself (measured:
    // ~74px half-width available at this row vs. the box's own ~60px
    // half-width, i.e. under 14px of slack per side) - these two icons are
    // deliberately tiny and tucked flush against the box edges rather than
    // given the same breathing room as the rest of the face's chrome, to
    // stay inside the bezel-safe circle at all. Noted explicitly in the
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

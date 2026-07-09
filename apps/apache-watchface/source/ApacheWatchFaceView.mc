import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.ActivityMonitor;
import Toybox.Application.Properties;

class ApacheWatchFaceView extends WatchUi.WatchFace {
    private const DAY_ABBREV as Array<String> = ["", "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];

    // Native bitmap pixel dimensions - fixed-size assets, not scaled at
    // runtime, so layout math below sizes rows around these constants
    // rather than the old "iconSize = boxH * fraction" live-vector
    // approach.
    private const BATTERY_W = 34.0;
    private const BATTERY_H = 18.0;
    private const HEART_W = 28.0;
    private const HEART_H = 28.0;
    private const BOOT_W = 36.0;   // side-profile boot silhouette - wider than tall
    private const BOOT_H = 24.0;
    private const SOLAR_W = 28.0;
    private const SOLAR_H = 28.0;
    private const WX_W = 32.0;
    private const WX_H = 32.0;
    private const BANNER_W = 220.0;  // full asset canvas; opaque wings+text content is ~180x34, centered inside it
    private const BANNER_H = 52.0;
    private const BT_W = 22.0;
    private const BT_H = 22.0;
    private const BELL_W = 24.0;
    private const BELL_H = 24.0;

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

    // No onPartialUpdate() override: the design hides seconds in Always-On
    // mode, so there's nothing that needs a per-second redraw while
    // sleeping. Without a partial-update handler the system falls back to
    // its default low-power behavior of calling onUpdate() once a minute -
    // which is exactly the "redraw only what changes, rarely" behavior the
    // battery-optimization brief asked for, for free.
    function onUpdate(dc as Graphics.Dc) as Void {
        _cache.refresh(_isSleeping);

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var cy = h / 2.0;
        var r = (w < h ? w : h) / 2.0;
        // Row-height/gap constants below are pixel-tuned against the real
        // fenix7xpro panel (280x280, r=140); `scale` keeps that tuning
        // proportionally correct if this ever runs on a different-radius
        // round display. The bitmap icons themselves are NOT scaled by
        // this factor - they're fixed-size assets, drawn 1:1 always.
        var scale = r / 140.0;

        dc.setColor(Graphics.COLOR_WHITE, ColorScheme.BACKGROUND);
        dc.clear();

        var textColor = ColorScheme.textColor(_isSleeping);
        var accentColor = ColorScheme.accentColor(_isSleeping);
        var panelColor = ColorScheme.panelColor(_isSleeping);

        // Row heights re-tuned against the real 280x280 (r=140) circle
        // geometry - see the design brief's pixel-budget table. Seven
        // full-size rows do not fit at this radius with generous sizing,
        // so weather and Bluetooth/notification status share one row
        // (split left/right) instead of each getting its own; that's the
        // one deliberate compromise. Everything else keeps its own row.
        // Client priority order (highest to lowest) still drives relative
        // sizing: clock+seconds > temp/weather > next solar event > heart
        // rate > steps > battery%. The AH-64E banner and the BT/notif
        // half of the combined row are the two lowest-priority elements -
        // sized last, with whatever room remains.
        var bannerH = 32.0 * scale;  // opaque wings+text artwork is ~34px tall, centered in a 52px canvas
        var row1H = 38.0 * scale;    // PWR / HR - battery 18h, heart 28h
        var clockH = 76.0 * scale;   // clock + seconds - top priority, biggest
        var row2H = 38.0 * scale;    // STP / SOLAR - boot 24h, solar 28h
        var dateH = 18.0 * scale;
        var wxBtH = 38.0 * scale;    // temp+weather (left) / BT+notifications (right) - shared row
        var gap = 3.0 * scale;

        // Banner doesn't exist in Always-On (decoration shouldn't survive
        // into low power) - two different stack heights, each internally
        // centered as its own block, so top margin ~= bottom margin holds
        // true in both modes even though awake mode has one more row.
        var showBanner = !_isSleeping;
        var stackH = row1H + clockH + row2H + dateH + wxBtH + (gap * 4);
        if (showBanner) {
            stackH += bannerH + gap;
        }

        var contentR = r * 0.95;
        var cursorY = cy - (stackH / 2.0);

        if (showBanner) {
            var bannerCY = cursorY + (bannerH / 2.0);
            drawBannerRow(dc, cx, bannerCY);
            cursorY += bannerH + gap;
        }

        var row1CY = cursorY + (row1H / 2.0);
        drawPwrHrRow(dc, cx, row1CY, row1H, safeHalfWidth(row1CY - cy, contentR), textColor, accentColor, panelColor);
        cursorY += row1H + gap;

        var clockCY = cursorY + (clockH / 2.0);
        drawClockRow(dc, cx, clockCY, clockH, safeHalfWidth(clockCY - cy, contentR), textColor, panelColor);
        cursorY += clockH + gap;

        var row2CY = cursorY + (row2H / 2.0);
        drawStpSolarRow(dc, cx, row2CY, row2H, safeHalfWidth(row2CY - cy, contentR), textColor, panelColor);
        cursorY += row2H + gap;

        var dateCY = cursorY + (dateH / 2.0);
        drawDateRow(dc, cx, dateCY, dateH, safeHalfWidth(dateCY - cy, contentR), textColor, panelColor);
        cursorY += dateH + gap;

        var wxBtCY = cursorY + (wxBtH / 2.0);
        drawWxBtRow(dc, cx, wxBtCY, wxBtH, safeHalfWidth(wxBtCY - cy, contentR), textColor, accentColor, panelColor);
    }

    // Half-width of the display available at a given vertical distance
    // `dy` from center, for a circle of radius `contentR`. Used to size
    // every row against the real round-display geometry instead of a
    // flat, eyeballed fraction of screen width.
    private function safeHalfWidth(dy as Float, contentR as Float) as Float {
        var v = (contentR * contentR) - (dy * dy);
        if (v < 0) {
            v = 0;
        }
        return Math.sqrt(v);
    }

    // Fixed 200x48 title banner, day-mode only. Callers must skip this
    // entirely while sleeping (checked here too, defensively) - it's pure
    // decoration and decoration doesn't survive into Always-On.
    private function drawBannerRow(dc as Graphics.Dc, cx as Float, cy as Float) as Void {
        if (_isSleeping) {
            return;
        }
        HudDraw.drawBitmapCentered(dc, cx, cy, _bannerAh64e, BANNER_W, BANNER_H);
    }

    private function drawPwrHrRow(dc as Graphics.Dc, cx as Float, cy as Float, rowH as Float, halfWidth as Float,
                                   textColor as Number, accentColor as Number, panelColor as Number) as Void {
        // This is the lowest-priority row in the client's ordering, and
        // it's also squeezed narrowest by round-display geometry (it sits
        // furthest from center, right under the bezel). Claim more of the
        // available halfWidth (0.94 vs. the 0.88 other rows use) and use a
        // slimmer gap between the two boxes to buy back room.
        var usableHalfWidth = halfWidth * 0.94;
        var boxGap = usableHalfWidth * 0.06;
        var boxW = usableHalfWidth - (boxGap / 2.0);
        var boxH = rowH * 0.90;

        var leftX0 = cx - usableHalfWidth;
        var rightX1 = cx + usableHalfWidth;
        var boxTop = cy - (boxH / 2.0);

        HudDraw.drawPanel(dc, leftX0, boxTop, boxW, boxH, panelColor);
        HudDraw.drawPanel(dc, rightX1 - boxW, boxTop, boxW, boxH, panelColor);

        var battery = System.getSystemStats().battery;
        var contentY = cy - (boxH * 0.08);
        // Stat text on this deprioritized row uses FONT_XTINY (a step down
        // from the FONT_SMALL other rows use) to keep both boxes from
        // crowding the fixed-size icon + "%"/BPM text into each other.
        var statFont = Graphics.FONT_XTINY;

        var battChrome = _isSleeping ? _iconBatteryChromeAod : _iconBatteryChromeDay;
        var battCX = leftX0 + (boxW * 0.20);
        HudDraw.drawBitmapCentered(dc, battCX, contentY, battChrome, BATTERY_W, BATTERY_H);
        // Vector fill on top of the outline+nub bitmap - the chrome asset
        // intentionally has no baked-in fill so one asset covers every
        // charge level.
        HudDraw.drawBatteryFill(dc, battCX - (BATTERY_W / 2.0), contentY - (BATTERY_H / 2.0), BATTERY_W, BATTERY_H, battery, accentColor);
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftX0 + (boxW * 0.93), contentY, statFont, battery.format("%d") + "%", Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        HudDraw.drawDashedLine(dc, leftX0 + (boxW * 0.10), leftX0 + (boxW * 0.90), boxTop + (boxH * 0.86), panelColor);

        var hrX0 = rightX1 - boxW;
        var hrText = "--";
        var hr = _cache.heartRate;
        if (hr != null) {
            hrText = hr.toString();
        }

        var heartIcon = _isSleeping ? _iconHeartAod : _iconHeartDay;
        HudDraw.drawBitmapCentered(dc, hrX0 + (boxW * 0.24), contentY, heartIcon, HEART_W, HEART_H);
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hrX0 + (boxW * 0.93), contentY, statFont, hrText, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        HudDraw.drawDashedLine(dc, hrX0 + (boxW * 0.10), hrX0 + (boxW * 0.90), boxTop + (boxH * 0.86), panelColor);
    }

    private function drawClockRow(dc as Graphics.Dc, cx as Float, cy as Float, rowH as Float, halfWidth as Float,
                                   textColor as Number, panelColor as Number) as Void {
        var boxHalfWidth = halfWidth * 0.95;
        var boxH = rowH * 0.92;
        HudDraw.drawPanel(dc, cx - boxHalfWidth, cy - (boxH / 2.0), boxHalfWidth * 2.0, boxH, panelColor);

        // Always 24-hour, regardless of device settings - client asked for
        // this explicitly. clockTime.hour is already 0-23, so this is just
        // zero-padding it directly with no 12-hour conversion or AM/PM
        // label.
        var clockTime = System.getClockTime();
        var timeStr = Lang.format("$1$:$2$", [clockTime.hour.format("%02d"), clockTime.min.format("%02d")]);

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Graphics.FONT_NUMBER_MEDIUM, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (!_isSleeping) {
            // Measure the actual rendered width of "HH:MM" at
            // FONT_NUMBER_MEDIUM so seconds are placed just past its right
            // edge. Seconds use a small plain text font (not a NUMBER
            // font) - at NUMBER-font scale they pushed past the panel's
            // right edge.
            var timeDims = dc.getTextDimensions(timeStr, Graphics.FONT_NUMBER_MEDIUM);
            var secStr = clockTime.sec.format("%02d");
            var secDims = dc.getTextDimensions(secStr, Graphics.FONT_TINY);
            var secX = cx + (timeDims[0] / 2.0) + (boxH * 0.04);

            // Clamp so seconds never render past the panel's right edge,
            // regardless of locale digit width.
            var maxSecX = cx + boxHalfWidth - secDims[0] - (boxH * 0.04);
            if (secX > maxSecX) {
                secX = maxSecX;
            }

            dc.drawText(secX, cy + (timeDims[1] * 0.22), Graphics.FONT_TINY, secStr,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function drawStpSolarRow(dc as Graphics.Dc, cx as Float, cy as Float, rowH as Float, halfWidth as Float,
                                      textColor as Number, panelColor as Number) as Void {
        var usableHalfWidth = halfWidth * 0.88;
        var boxGap = usableHalfWidth * 0.10;
        var boxW = usableHalfWidth - (boxGap / 2.0);
        var boxH = rowH * 0.90;

        var leftX0 = cx - usableHalfWidth;
        var rightX1 = cx + usableHalfWidth;
        var boxTop = cy - (boxH / 2.0);

        HudDraw.drawPanel(dc, leftX0, boxTop, boxW, boxH, panelColor);
        HudDraw.drawPanel(dc, rightX1 - boxW, boxTop, boxW, boxH, panelColor);

        var contentY = cy - (boxH * 0.08);

        var stepsText = "--";
        var info = ActivityMonitor.getInfo();
        if (info != null && info.steps != null) {
            stepsText = info.steps.toString();
        }

        var bootIcon = _isSleeping ? _iconBootAod : _iconBootDay;
        HudDraw.drawBitmapCentered(dc, leftX0 + (boxW * 0.26), contentY, bootIcon, BOOT_W, BOOT_H);
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftX0 + (boxW * 0.92), contentY, Graphics.FONT_SMALL, stepsText, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        HudDraw.drawDashedLine(dc, leftX0 + (boxW * 0.10), leftX0 + (boxW * 0.90), boxTop + (boxH * 0.86), panelColor);

        var solarX0 = rightX1 - boxW;
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
        HudDraw.drawBitmapCentered(dc, solarX0 + (boxW * 0.26), contentY, solarIcon, SOLAR_W, SOLAR_H);
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(solarX0 + (boxW * 0.92), contentY, Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        HudDraw.drawDashedLine(dc, solarX0 + (boxW * 0.10), solarX0 + (boxW * 0.90), boxTop + (boxH * 0.86), panelColor);
    }

    private function drawDateRow(dc as Graphics.Dc, cx as Float, cy as Float, rowH as Float, halfWidth as Float,
                                  textColor as Number, panelColor as Number) as Void {
        var boxHalfWidth = halfWidth * 0.72;
        var boxH = rowH * 0.90;
        HudDraw.drawPanel(dc, cx - boxHalfWidth, cy - (boxH / 2.0), boxHalfWidth * 2.0, boxH, panelColor);

        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dayName = DAY_ABBREV[info.day_of_week];
        var ddMm = Properties.getValue("dateFormatDDMM") as Number;
        var dateNums = (ddMm == 1)
            ? Lang.format("$1$/$2$", [info.day.format("%02d"), info.month.format("%02d")])
            : Lang.format("$1$/$2$", [info.month.format("%02d"), info.day.format("%02d")]);

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Graphics.FONT_SMALL, dayName + " " + dateNums, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Bottom-most, narrowest row on the face (per round-display geometry
    // this close to the bezel there isn't room for weather, Bluetooth, and
    // notifications as three separate rows) - so this is the one
    // deliberate layout compromise: weather (icon+temp) on the left half,
    // Bluetooth connection + unread notification count on the right half,
    // both inside their own octagon panel like every other stat pair.
    // Weather keeps its #2 client priority (sized via wxBtH same as any
    // other stat row); BT/notifications are the lowest-priority element on
    // the face and just take whatever the right half offers. This row is
    // live status, not pure decoration, so unlike the banner it's drawn
    // (dimmed) in Always-On too.
    private function drawWxBtRow(dc as Graphics.Dc, cx as Float, cy as Float, rowH as Float, halfWidth as Float,
                                  textColor as Number, accentColor as Number, panelColor as Number) as Void {
        var usableHalfWidth = halfWidth * 0.92;
        var boxGap = usableHalfWidth * 0.08;
        var boxW = usableHalfWidth - (boxGap / 2.0);
        var boxH = rowH * 0.90;

        var leftX0 = cx - usableHalfWidth;
        var rightX1 = cx + usableHalfWidth;
        var boxTop = cy - (boxH / 2.0);

        HudDraw.drawPanel(dc, leftX0, boxTop, boxW, boxH, panelColor);
        HudDraw.drawPanel(dc, rightX1 - boxW, boxTop, boxW, boxH, panelColor);

        var contentY = cy - (boxH * 0.08);
        var statFont = Graphics.FONT_XTINY;

        // Left box: weather icon + temperature.
        var fullBucket = HudDraw.mapConditionToBucket(_cache.weatherCondition);
        var icon;
        if (_isSleeping) {
            // Always-On simplifies to 2 states per the brief: clear/cloudy
            // collapse to the plain clear glyph, everything else (overcast,
            // rain, snow, storm) collapses to the plain overcast glyph.
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

        HudDraw.drawBitmapCentered(dc, leftX0 + (boxW * 0.28), contentY, icon, WX_W, WX_H);
        var tempText = formatTemperature(_cache.weatherTemperatureC);
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftX0 + (boxW * 0.94), contentY, statFont, tempText, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        HudDraw.drawDashedLine(dc, leftX0 + (boxW * 0.10), leftX0 + (boxW * 0.90), boxTop + (boxH * 0.86), panelColor);

        // Right box: Bluetooth connection glyph (+ a small connected/
        // disconnected status dot) and the notification bell with a live
        // unread count badge - skipped entirely when the count is 0 so an
        // empty inbox doesn't draw a stray "0".
        var rightX0 = rightX1 - boxW;
        // System.getDeviceSettings() and its phoneConnected/notificationCount
        // fields are all non-nullable per the API docs, so no null-guarding
        // needed here (unlike the sensor/GPS reads elsewhere in this file).
        var deviceSettings = System.getDeviceSettings();
        var phoneConnected = deviceSettings.phoneConnected;
        var notifCount = deviceSettings.notificationCount;

        var btIcon = _isSleeping ? _iconBluetoothAod : _iconBluetoothDay;
        var bellIcon = _isSleeping ? _iconBellAod : _iconBellDay;

        var btCX = rightX0 + (boxW * 0.10) + (BT_W / 2.0);
        HudDraw.drawBitmapCentered(dc, btCX, contentY, btIcon, BT_W, BT_H);

        // Connection-status dot is live state, not decoration - shown
        // (dimmed via accentColor already being the AOD-appropriate value)
        // in both modes: accent color when the phone link is up, dim panel
        // color when it's down.
        var dotColor = phoneConnected ? accentColor : panelColor;
        dc.setColor(dotColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(btCX + (BT_W * 0.32), contentY + (BT_H * 0.32), boxH * 0.08);

        var bellCX = btCX + (BT_W / 2.0) + (boxW * 0.10) + (BELL_W / 2.0);
        HudDraw.drawBitmapCentered(dc, bellCX, contentY, bellIcon, BELL_W, BELL_H);

        if (notifCount > 0) {
            var countText = (notifCount > 9) ? "9+" : notifCount.toString();
            dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(rightX1 - (boxW * 0.06), contentY, statFont, countText, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        HudDraw.drawDashedLine(dc, rightX0 + (boxW * 0.10), rightX0 + (boxW * 0.90), boxTop + (boxH * 0.86), panelColor);
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

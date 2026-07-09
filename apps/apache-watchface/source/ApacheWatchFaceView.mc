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

    private var _cache as DataCache;
    private var _isSleeping as Boolean = false;

    function initialize() {
        WatchFace.initialize();
        _cache = new DataCache();
    }

    function onLayout(dc as Graphics.Dc) as Void {
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

        dc.setColor(Graphics.COLOR_WHITE, ColorScheme.BACKGROUND);
        dc.clear();

        var textColor = ColorScheme.textColor(_isSleeping);
        var accentColor = ColorScheme.accentColor(_isSleeping);
        var solarColor = ColorScheme.solarColor(_isSleeping);
        var heartColor = ColorScheme.heartColor(_isSleeping);
        var panelColor = ColorScheme.panelColor(_isSleeping);

        // Chapter ring + gauge arc removed per client feedback (it read as
        // a broken spiral, and solar intensity isn't a field worth a
        // dedicated decoration). Removing it frees up radial/vertical
        // space that now goes to `contentR` and to the rows themselves -
        // see the row-height comment below.
        //
        // The whole content stack is vertically centered as a block (top
        // margin == bottom margin by construction), rather than eyeballed
        // per-row fractions - see Mobius's centering checklist. Row
        // heights are sized by explicit client priority order (highest to
        // lowest): clock+seconds > temp/weather > next solar event > heart
        // rate > steps > battery%. Date wasn't asked to shrink or be
        // removed, but is lowest priority among the labeled rows since it
        // wasn't called out as "must see at a glance."
        var row1H = r * 0.26;   // PWR / HR
        var clockH = r * 0.58;  // clock + seconds - top priority, biggest
        var row2H = r * 0.30;   // STP / SOLAR
        var dateH = r * 0.19;
        var wxH = r * 0.27;     // temp + weather - #2 priority
        var gap = r * 0.045;

        var stackH = row1H + clockH + row2H + dateH + wxH + (gap * 4);
        var contentR = r * 0.95;
        var cursorY = cy - (stackH / 2.0);

        var row1CY = cursorY + (row1H / 2.0);
        drawPwrHrRow(dc, cx, row1CY, row1H, safeHalfWidth(row1CY - cy, contentR), textColor, accentColor, heartColor, panelColor);
        cursorY += row1H + gap;

        var clockCY = cursorY + (clockH / 2.0);
        drawClockRow(dc, cx, clockCY, clockH, safeHalfWidth(clockCY - cy, contentR), textColor, panelColor);
        cursorY += clockH + gap;

        var row2CY = cursorY + (row2H / 2.0);
        drawStpSolarRow(dc, cx, row2CY, row2H, safeHalfWidth(row2CY - cy, contentR), textColor, accentColor, solarColor, panelColor);
        cursorY += row2H + gap;

        var dateCY = cursorY + (dateH / 2.0);
        drawDateRow(dc, cx, dateCY, dateH, safeHalfWidth(dateCY - cy, contentR), textColor, panelColor);
        cursorY += dateH + gap;

        var wxCY = cursorY + (wxH / 2.0);
        drawWxRow(dc, cx, wxCY, wxH, safeHalfWidth(wxCY - cy, contentR), textColor, accentColor, panelColor);
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

    private function drawPwrHrRow(dc as Graphics.Dc, cx as Float, cy as Float, rowH as Float, halfWidth as Float,
                                   textColor as Number, accentColor as Number, heartColor as Number, panelColor as Number) as Void {
        // This is the lowest-priority row in the client's ordering, and
        // it's also squeezed narrowest by round-display geometry (it sits
        // furthest from center, right under the bezel). Claim more of the
        // available halfWidth (0.94 vs. the 0.88 other rows use) and use a
        // slimmer gap between the two boxes to buy back room, rather than
        // just shrinking the icon until it's unrecognizable.
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
        // Clamp to the narrower of the two box dimensions so icons can
        // never eat into the text regardless of how row heights above get
        // retuned later.
        var iconSize = (boxW < boxH ? boxW : boxH) * 0.44;
        // drawBattery's bounding box is a literal rectangle (bw == size),
        // unlike drawHeart which scales its lobes down to well inside its
        // `size` box - so at the same iconSize the battery glyph reaches
        // further right and crowds the "%" text. Give it a modestly
        // smaller size and a further-left anchor instead of sharing the
        // row's iconSize outright. Stat text on this deprioritized row
        // uses FONT_XTINY (a step down from the FONT_SMALL other rows
        // use) specifically to buy the battery icon enough width to still
        // read as a battery rather than a smudge.
        var batteryIconSize = iconSize * 0.80;
        var contentY = cy - (boxH * 0.08);
        var statFont = Graphics.FONT_XTINY;

        HudDraw.drawBattery(dc, leftX0 + (boxW * 0.20), contentY, batteryIconSize, battery, accentColor);
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftX0 + (boxW * 0.93), contentY, statFont, battery.format("%d") + "%", Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        HudDraw.drawDashedLine(dc, leftX0 + (boxW * 0.10), leftX0 + (boxW * 0.90), boxTop + (boxH * 0.86), panelColor);

        var hrX0 = rightX1 - boxW;
        var hrText = "--";
        var hr = _cache.heartRate;
        if (hr != null) {
            hrText = hr.toString();
        }

        HudDraw.drawHeart(dc, hrX0 + (boxW * 0.24), contentY, iconSize, heartColor);
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
        // label. Removing the label also frees the vertical space below
        // the clock that used to be reserved for it.
        var clockTime = System.getClockTime();
        var timeStr = Lang.format("$1$:$2$", [clockTime.hour.format("%02d"), clockTime.min.format("%02d")]);

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Graphics.FONT_NUMBER_MEDIUM, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (!_isSleeping) {
            // Measure the actual rendered width of "HH:MM" at
            // FONT_NUMBER_MEDIUM so seconds are placed just past its right
            // edge - re-measured here (not reused from the old
            // FONT_NUMBER_HOT pass) since the font size changed and a
            // stale offset would jam seconds against the panel/ring edge
            // or overlap the minutes digits. Seconds use a small plain
            // text font (not a NUMBER font) - at NUMBER-font scale they
            // pushed past the panel's right edge into the chapter ring.
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
                                      textColor as Number, accentColor as Number, solarColor as Number, panelColor as Number) as Void {
        var usableHalfWidth = halfWidth * 0.88;
        var boxGap = usableHalfWidth * 0.10;
        var boxW = usableHalfWidth - (boxGap / 2.0);
        var boxH = rowH * 0.90;

        var leftX0 = cx - usableHalfWidth;
        var rightX1 = cx + usableHalfWidth;
        var boxTop = cy - (boxH / 2.0);

        HudDraw.drawPanel(dc, leftX0, boxTop, boxW, boxH, panelColor);
        HudDraw.drawPanel(dc, rightX1 - boxW, boxTop, boxW, boxH, panelColor);

        // This row sits close to vertical center, so boxW is generously
        // wider than boxH here and boxH is always the binding constraint -
        // but clamp on the narrower dimension anyway (same pattern as
        // drawPwrHrRow) so this stays overlap-safe if row heights are
        // retuned later.
        var iconSize = (boxW < boxH ? boxW : boxH) * 0.50;
        var contentY = cy - (boxH * 0.08);

        var stepsText = "--";
        var info = ActivityMonitor.getInfo();
        if (info != null && info.steps != null) {
            stepsText = info.steps.toString();
        }

        HudDraw.drawSteps(dc, leftX0 + (boxW * 0.26), contentY, iconSize, accentColor);
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

        HudDraw.drawSolarEvent(dc, solarX0 + (boxW * 0.26), contentY, iconSize, isRise, solarColor);
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

    private function drawWxRow(dc as Graphics.Dc, cx as Float, cy as Float, rowH as Float, halfWidth as Float,
                                textColor as Number, accentColor as Number, panelColor as Number) as Void {
        var boxHalfWidth = halfWidth * 0.62;
        var boxH = rowH * 0.94;
        HudDraw.drawPanel(dc, cx - boxHalfWidth, cy - (boxH / 2.0), boxHalfWidth * 2.0, boxH, panelColor);

        // WX is the shortest row in the stack (rowH = r * 0.20), so a
        // fraction that reads fine on a taller row (e.g. 0.46) shrinks the
        // icon here to a ~11px bounding box - individually correct shapes
        // that are simply too small to perceive on the real device. Give
        // the icon nearly the full box height instead.
        var iconX = cx - (boxHalfWidth * 0.46);
        var iconSize = boxH * 0.86;

        var fullBucket = HudDraw.mapConditionToBucket(_cache.weatherCondition);
        // Always-On mode shows a single simplified glyph (sunny or cloudy)
        // rather than the full 5-icon set, per the brief.
        var bucket = fullBucket;
        if (_isSleeping) {
            bucket = (fullBucket == :sunny) ? :sunny : :cloudy;
        }

        HudDraw.drawWeatherIcon(dc, iconX, cy, iconSize, bucket, accentColor);

        var tempText = formatTemperature(_cache.weatherTemperatureC);
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + (boxHalfWidth * 0.38), cy, Graphics.FONT_SMALL, tempText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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

import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Lang;
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
        var cx = w / 2;
        var cy = h / 2;

        dc.setColor(Graphics.COLOR_WHITE, ColorScheme.BACKGROUND);
        dc.clear();

        var textColor = ColorScheme.textColor(_isSleeping);
        var accentColor = ColorScheme.accentColor(_isSleeping);
        var solarColor = ColorScheme.solarColor(_isSleeping);
        var heartColor = ColorScheme.heartColor(_isSleeping);

        HudDraw.drawCornerBrackets(dc, w, h, accentColor);

        drawCenterTime(dc, cx, cy, textColor);
        drawBatteryField(dc, w, h, textColor, accentColor);
        drawHeartRateField(dc, w, h, textColor, heartColor);
        drawStepsField(dc, w, h, textColor, accentColor);
        drawSolarField(dc, w, h, textColor, solarColor);
        drawDateField(dc, w, h, textColor);
        drawWeatherField(dc, w, h, textColor, accentColor);
    }

    private function drawCenterTime(dc as Graphics.Dc, cx as Number, cy as Number, color as Number) as Void {
        var clockTime = System.getClockTime();
        var is24Hour = System.getDeviceSettings().is24Hour;
        var hour = clockTime.hour;
        var amPm = "";

        if (!is24Hour) {
            amPm = (hour >= 12) ? "PM" : "AM";
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
        }

        var timeStr = Lang.format("$1$:$2$", [hour.format("%02d"), clockTime.min.format("%02d")]);

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Graphics.FONT_NUMBER_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (!is24Hour) {
            dc.drawText(cx, cy + (dc.getHeight() * 0.16).toNumber(), Graphics.FONT_XTINY, amPm, Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (!_isSleeping) {
            var secStr = clockTime.sec.format("%02d");
            var secX = cx + (dc.getWidth() * 0.30).toNumber();
            var secY = cy + (dc.getHeight() * 0.06).toNumber();
            dc.drawText(secX, secY, Graphics.FONT_NUMBER_MEDIUM, secStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function drawBatteryField(dc as Graphics.Dc, w as Number, h as Number, textColor as Number, accentColor as Number) as Void {
        var x = (w * 0.22).toNumber();
        var iconY = (h * 0.15).toNumber();
        var textY = (h * 0.21).toNumber();
        var iconSize = (w * 0.10).toNumber();

        var battery = System.getSystemStats().battery;

        HudDraw.drawBattery(dc, x, iconY, iconSize, battery, accentColor);
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, textY, Graphics.FONT_XTINY, battery.format("%d") + "%", Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawHeartRateField(dc as Graphics.Dc, w as Number, h as Number, textColor as Number, heartColor as Number) as Void {
        var x = (w * 0.78).toNumber();
        var iconY = (h * 0.15).toNumber();
        var textY = (h * 0.21).toNumber();
        var iconSize = (w * 0.09).toNumber();

        var hrText = "--";
        var hr = _cache.heartRate;
        if (hr != null) {
            hrText = hr.toString();
        }

        HudDraw.drawHeart(dc, x, iconY, iconSize, heartColor);
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, textY, Graphics.FONT_XTINY, hrText, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawStepsField(dc as Graphics.Dc, w as Number, h as Number, textColor as Number, accentColor as Number) as Void {
        var x = (w * 0.22).toNumber();
        var iconY = (h * 0.66).toNumber();
        var textY = (h * 0.72).toNumber();
        var iconSize = (w * 0.09).toNumber();

        var stepsText = "--";
        var info = ActivityMonitor.getInfo();
        if (info != null && info.steps != null) {
            stepsText = info.steps.toString();
        }

        HudDraw.drawSteps(dc, x, iconY, iconSize, accentColor);
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, textY, Graphics.FONT_XTINY, stepsText, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawSolarField(dc as Graphics.Dc, w as Number, h as Number, textColor as Number, solarColor as Number) as Void {
        var x = (w * 0.78).toNumber();
        var iconY = (h * 0.66).toNumber();
        var textY = (h * 0.72).toNumber();
        var iconSize = (w * 0.11).toNumber();

        var label = "--:--";
        var isRise = true;
        var evLabel = _cache.solarEventLabel;
        var evMoment = _cache.solarEventMoment;
        if (evLabel != null && evMoment != null) {
            isRise = evLabel.equals("RISE");
            var info = Gregorian.info(evMoment, Time.FORMAT_SHORT);
            label = Lang.format("$1$:$2$", [info.hour.format("%02d"), info.min.format("%02d")]);
        }

        HudDraw.drawSolarEvent(dc, x, iconY, iconSize, isRise, solarColor);
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, textY, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawDateField(dc as Graphics.Dc, w as Number, h as Number, textColor as Number) as Void {
        var cx = w / 2;
        var y = (h * 0.76).toNumber();

        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dayName = DAY_ABBREV[info.day_of_week];
        var ddMm = Properties.getValue("dateFormatDDMM") as Number;
        var dateNums = (ddMm == 1)
            ? Lang.format("$1$/$2$", [info.day.format("%02d"), info.month.format("%02d")])
            : Lang.format("$1$/$2$", [info.month.format("%02d"), info.day.format("%02d")]);

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_SMALL, dayName + " " + dateNums, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawWeatherField(dc as Graphics.Dc, w as Number, h as Number, textColor as Number, accentColor as Number) as Void {
        var cx = w / 2;
        var iconY = (h * 0.90).toNumber();
        var iconSize = (w * 0.10).toNumber();
        var iconX = cx - (w * 0.14).toNumber();
        var textX = cx + (w * 0.06).toNumber();

        var fullBucket = HudDraw.mapConditionToBucket(_cache.weatherCondition);
        // Always-On mode shows a single simplified glyph (sunny or cloudy)
        // rather than the full 5-icon set, per the brief.
        var bucket = fullBucket;
        if (_isSleeping) {
            bucket = (fullBucket == :sunny) ? :sunny : :cloudy;
        }

        HudDraw.drawWeatherIcon(dc, iconX, iconY, iconSize, bucket, accentColor);

        var tempText = formatTemperature(_cache.weatherTemperatureC);
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(textX, iconY, Graphics.FONT_SMALL, tempText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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

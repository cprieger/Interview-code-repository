import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Weather;

// Small vector icon glyphs, drawn programmatically (no bitmap assets) in
// the AH-64E MFD/HUD style: flat fills, no gradients, legible on a MIP
// display. `size` is the icon's target bounding box in pixels.
module HudDraw {

    // Corner brackets framing the screen, like a HUD reticle border.
    function drawCornerBrackets(dc as Graphics.Dc, w as Number, h as Number, color as Number) as Void {
        var len = (w * 0.09).toNumber();
        var inset = (w * 0.08).toNumber();
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);

        // top-left
        dc.drawLine(inset, inset, inset + len, inset);
        dc.drawLine(inset, inset, inset, inset + len);
        // top-right
        dc.drawLine(w - inset, inset, w - inset - len, inset);
        dc.drawLine(w - inset, inset, w - inset, inset + len);
        // bottom-left
        dc.drawLine(inset, h - inset, inset + len, h - inset);
        dc.drawLine(inset, h - inset, inset, h - inset - len);
        // bottom-right
        dc.drawLine(w - inset, h - inset, w - inset - len, h - inset);
        dc.drawLine(w - inset, h - inset, w - inset, h - inset - len);
    }

    // Battery outline with a fill proportional to charge percent.
    function drawBattery(dc as Graphics.Dc, x as Number, y as Number, size as Number, percent as Float, color as Number) as Void {
        var bw = size;
        var bh = (size * 0.55).toNumber();
        var nub = (size * 0.12).toNumber();
        var left = x - (bw / 2);
        var top = y - (bh / 2);

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRectangle(left, top, bw - nub, bh);
        dc.fillRectangle(left + bw - nub, top + (bh * 0.25).toNumber(), nub, (bh * 0.5).toNumber());

        var fillW = (((bw - nub - 4) * (percent / 100.0))).toNumber();
        if (fillW > 0) {
            dc.fillRectangle(left + 2, top + 2, fillW, bh - 4);
        }
    }

    // Simple blocky heart, drawn as a filled polygon.
    function drawHeart(dc as Graphics.Dc, x as Number, y as Number, size as Number, color as Number) as Void {
        var s = size / 2.0;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [x, y + s * 0.9],
            [x - s, y - s * 0.1],
            [x - s * 0.5, y - s],
            [x, y - s * 0.4],
            [x + s * 0.5, y - s],
            [x + s, y - s * 0.1]
        ] as Array<[Numeric, Numeric]>);
    }

    // Two overlapping "footprint" blobs.
    function drawSteps(dc as Graphics.Dc, x as Number, y as Number, size as Number, color as Number) as Void {
        var r = size * 0.28;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - (size * 0.2).toNumber(), y + (size * 0.15).toNumber(), r);
        dc.fillCircle(x + (size * 0.2).toNumber(), y - (size * 0.15).toNumber(), r);
    }

    // Sun-on-horizon with an up/down arrow for sunrise/sunset.
    function drawSolarEvent(dc as Graphics.Dc, x as Number, y as Number, size as Number, isRise as Boolean, color as Number) as Void {
        var r = size * 0.22;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.fillCircle(x - (size * 0.15).toNumber(), y, r);
        dc.drawLine(x - size * 0.55, y + r * 0.9, x + size * 0.15, y + r * 0.9);

        var ax = x + (size * 0.42).toNumber();
        var ah = size * 0.32;
        if (isRise) {
            dc.fillPolygon([
                [ax, y - ah],
                [ax - ah * 0.6, y + ah * 0.4],
                [ax + ah * 0.6, y + ah * 0.4]
            ] as Array<[Numeric, Numeric]>);
        } else {
            dc.fillPolygon([
                [ax, y + ah],
                [ax - ah * 0.6, y - ah * 0.4],
                [ax + ah * 0.6, y - ah * 0.4]
            ] as Array<[Numeric, Numeric]>);
        }
    }

    // Rounded-rectangle "cloud" used as the base of several weather icons.
    // (Not marked private - Monkey C's `module` doesn't support access modifiers on functions, only `class` does.)
    function drawCloudBase(dc as Graphics.Dc, x as Number, y as Number, size as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var r = size * 0.22;
        dc.fillCircle(x - (size * 0.22).toNumber(), y, r);
        dc.fillCircle(x + (size * 0.05).toNumber(), y - (size * 0.12).toNumber(), r * 1.15);
        dc.fillCircle(x + (size * 0.32).toNumber(), y, r * 0.9);
        dc.fillRectangle(x - (size * 0.22).toNumber(), y, (size * 0.56).toNumber(), (r).toNumber());
    }

    function drawWeatherIcon(dc as Graphics.Dc, x as Number, y as Number, size as Number, bucket as Symbol, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);

        if (bucket == :sunny) {
            var r = size * 0.26;
            dc.fillCircle(x, y, r);
            for (var i = 0; i < 8; i++) {
                var ang = i * Math.PI / 4.0;
                var x0 = x + (r * 1.3) * Math.cos(ang);
                var y0 = y + (r * 1.3) * Math.sin(ang);
                var x1 = x + (r * 1.9) * Math.cos(ang);
                var y1 = y + (r * 1.9) * Math.sin(ang);
                dc.drawLine(x0, y0, x1, y1);
            }
            return;
        }

        if (bucket == :cloudy) {
            drawCloudBase(dc, x, y, size, color);
            return;
        }

        if (bucket == :rain) {
            drawCloudBase(dc, x, y - (size * 0.12).toNumber(), size, color);
            var by = y + (size * 0.18).toNumber();
            for (var i = -1; i <= 1; i++) {
                var lx = x + i * (size * 0.22).toNumber();
                dc.drawLine(lx, by, lx - (size * 0.08).toNumber(), by + (size * 0.22).toNumber());
            }
            return;
        }

        if (bucket == :snow) {
            drawCloudBase(dc, x, y - (size * 0.12).toNumber(), size, color);
            var by2 = y + (size * 0.22).toNumber();
            for (var i = -1; i <= 1; i++) {
                var dotx = x + i * (size * 0.22).toNumber();
                dc.fillCircle(dotx, by2, size * 0.045);
            }
            return;
        }

        if (bucket == :storm) {
            drawCloudBase(dc, x, y - (size * 0.14).toNumber(), size, color);
            var bx = x + (size * 0.02).toNumber();
            var by3 = y + (size * 0.12).toNumber();
            dc.fillPolygon([
                [bx + size * 0.08, by3],
                [bx - size * 0.08, by3 + size * 0.22],
                [bx + size * 0.02, by3 + size * 0.22],
                [bx - size * 0.1, by3 + size * 0.44],
                [bx + size * 0.16, by3 + size * 0.16],
                [bx + size * 0.02, by3 + size * 0.16]
            ] as Array<[Numeric, Numeric]>);
            return;
        }

        // Fallback: unknown bucket, draw a plain cloud.
        drawCloudBase(dc, x, y, size, color);
    }

    // Maps the (large) Weather.CONDITION_* enum down to the 5 icon buckets
    // the client asked for. Only uses condition constants confirmed present
    // since the Weather module's original 3.1.0 release; extend this list
    // with more CONDITION_* values from the API docs if you want finer
    // distinctions (e.g. separate "flurries" vs "heavy snow" icons).
    function mapConditionToBucket(condition as Number?) as Symbol {
        if (condition == null) {
            return :cloudy;
        }

        if (condition == Weather.CONDITION_CLEAR || condition == Weather.CONDITION_FAIR) {
            return :sunny;
        }

        if (condition == Weather.CONDITION_RAIN
            || condition == Weather.CONDITION_LIGHT_RAIN
            || condition == Weather.CONDITION_HEAVY_RAIN) {
            return :rain;
        }

        if (condition == Weather.CONDITION_SNOW
            || condition == Weather.CONDITION_LIGHT_SNOW
            || condition == Weather.CONDITION_HEAVY_SNOW
            || condition == Weather.CONDITION_WINTRY_MIX
            || condition == Weather.CONDITION_HAIL) {
            return :snow;
        }

        if (condition == Weather.CONDITION_THUNDERSTORMS
            || condition == Weather.CONDITION_SCATTERED_THUNDERSTORMS) {
            return :storm;
        }

        if (condition == Weather.CONDITION_PARTLY_CLOUDY
            || condition == Weather.CONDITION_MOSTLY_CLOUDY
            || condition == Weather.CONDITION_CLOUDY
            || condition == Weather.CONDITION_FOG
            || condition == Weather.CONDITION_HAZY
            || condition == Weather.CONDITION_WINDY
            || condition == Weather.CONDITION_UNKNOWN) {
            return :cloudy;
        }

        return :cloudy;
    }
}

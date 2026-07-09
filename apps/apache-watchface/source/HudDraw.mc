import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Weather;

// Small vector icon glyphs, drawn programmatically (no bitmap assets) in
// the AH-64E MFD/HUD style: flat fills, no gradients, legible on a MIP
// display. `size` is the icon's target bounding box in pixels.
module HudDraw {

    // Octagon ("clipped-corner") panel outline - the field-group framing
    // used throughout the phosphor-LCD look. Unfilled: Dc has no
    // multi-point outline primitive, so this walks the 8 corner points
    // with drawLine rather than relying on a "drawPolygon" that may not
    // exist across SDK versions.
    function drawPanel(dc as Graphics.Dc, x as Float, y as Float, w as Float, h as Float, color as Number) as Void {
        var cut = (w < h ? w : h) * 0.16;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var pts = [
            [x + cut, y], [x + w - cut, y],
            [x + w, y + cut], [x + w, y + h - cut],
            [x + w - cut, y + h], [x + cut, y + h],
            [x, y + h - cut], [x, y + cut]
        ] as Array<[Numeric, Numeric]>;
        var n = pts.size();
        for (var i = 0; i < n; i++) {
            var p1 = pts[i];
            var p2 = pts[(i + 1) % n];
            dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
        }
    }

    // Short segmented "loading bar" style divider under a stat row. Dc has
    // no dashed-stroke primitive, so this hand-draws the dash segments.
    function drawDashedLine(dc as Graphics.Dc, x1 as Float, x2 as Float, y as Float, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        var dash = 7.0;
        var gap = 5.0;
        var x = x1;
        while (x < x2) {
            var xEnd = x + dash;
            if (xEnd > x2) {
                xEnd = x2;
            }
            dc.drawLine(x, y, xEnd, y);
            x += dash + gap;
        }
    }

    // Interpolates linearly between two 0xRRGGBB colors at t in [0,1].
    function lerpColor(c1 as Number, c2 as Number, t as Float) as Number {
        var r1 = (c1 >> 16) & 0xFF;
        var g1 = (c1 >> 8) & 0xFF;
        var b1 = c1 & 0xFF;
        var r2 = (c2 >> 16) & 0xFF;
        var g2 = (c2 >> 8) & 0xFF;
        var b2 = c2 & 0xFF;
        var r = (r1 + (r2 - r1) * t).toNumber();
        var g = (g1 + (g2 - g1) * t).toNumber();
        var b = (b1 + (b2 - b1) * t).toNumber();
        return (r << 16) | (g << 8) | b;
    }

    // Battery outline with a segmented (4-bar) fill lit proportionally to
    // charge percent, matching the approved concept - a discrete gauge
    // reads as intentional at a glance; a single continuous proportional
    // fill just looked like a smear at real on-device icon sizes.
    function drawBattery(dc as Graphics.Dc, x as Numeric, y as Numeric, size as Numeric, percent as Float, color as Number) as Void {
        var bw = size;
        var bh = (size * 0.55).toNumber();
        var nub = (size * 0.12).toNumber();
        var left = x - (bw / 2);
        var top = y - (bh / 2);

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRectangle(left, top, bw - nub, bh);
        dc.fillRectangle(left + bw - nub, top + (bh * 0.25).toNumber(), nub, (bh * 0.5).toNumber());

        var segCount = 4;
        var innerW = bw - nub - 4;
        var innerH = bh - 4;
        var segGap = 2.0;
        var segW = (innerW - (segGap * (segCount - 1))) / segCount;
        if (segW < 1) {
            segW = 1;
        }
        var litSegs = Math.ceil((percent / 100.0) * segCount).toNumber();
        if (percent > 0 && litSegs < 1) {
            litSegs = 1;
        }
        for (var i = 0; i < segCount; i++) {
            if (i >= litSegs) {
                continue;
            }
            var segX = left + 2 + (i * (segW + segGap));
            dc.fillRectangle(segX, top + 2, segW, innerH);
        }
    }

    // Heart as two circular lobes + a filled triangle point, rather than a
    // single zigzag polygon - reads reliably as a heart silhouette at the
    // small icon sizes stat rows actually render at, where the previous
    // polygon's notch collapsed into an indistinct blob.
    function drawHeart(dc as Graphics.Dc, x as Numeric, y as Numeric, size as Numeric, color as Number) as Void {
        var s = size * 0.62;
        var lobeR = s * 0.42;
        var lobeY = y - s * 0.28;
        var lobeOffsetX = s * 0.40;

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - lobeOffsetX, lobeY, lobeR);
        dc.fillCircle(x + lobeOffsetX, lobeY, lobeR);
        dc.fillPolygon([
            [x - s * 0.82, lobeY + lobeR * 0.35],
            [x + s * 0.82, lobeY + lobeR * 0.35],
            [x, y + s * 0.78]
        ] as Array<[Numeric, Numeric]>);
    }

    // Single foot silhouette: an elongated sole with one larger toe-cap
    // circle overlapping its top, offset to one side. A first pass at this
    // used three small toe dots, but at real on-device icon sizes they sat
    // close enough to the sole to merge into it, reading as a single
    // undifferentiated teardrop instead of a foot. One bigger, clearly
    // asymmetric toe cap reads more reliably at small scale than three
    // dots that can't survive the shrink.
    function drawSteps(dc as Graphics.Dc, x as Numeric, y as Numeric, size as Numeric, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);

        var soleRx = size * 0.22;
        var soleRy = size * 0.34;
        var soleCy = y + size * 0.16;
        var pts = [] as Array<[Numeric, Numeric]>;
        var segs = 14;
        for (var i = 0; i < segs; i++) {
            var ang = (i.toFloat() / segs) * 2.0 * Math.PI;
            pts.add([x + soleRx * Math.cos(ang), soleCy + soleRy * Math.sin(ang)] as [Numeric, Numeric]);
        }
        dc.fillPolygon(pts);

        var toeR = size * 0.20;
        dc.fillCircle(x + size * 0.05, y - size * 0.26, toeR);
    }

    // Sun-on-horizon with an up/down arrow for sunrise/sunset. The
    // previous pass placed the horizon line so close to the sun's radius
    // that it cut through the lower part of the circle, and the arrow so
    // close to the sun that the two merged into a single "mountain peaks"
    // blob instead of reading as separate sun/horizon/arrow elements.
    // This version keeps the horizon line tangent below the sun (not
    // intersecting it) and gives the arrow a clear horizontal gap.
    function drawSolarEvent(dc as Graphics.Dc, x as Numeric, y as Numeric, size as Numeric, isRise as Boolean, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);

        var r = size * 0.26;
        var sunX = x - size * 0.30;
        var horizonY = y + r + (size * 0.08); // clear gap below the sun, not through it
        dc.fillCircle(sunX, y, r);
        dc.drawLine(x - size * 0.62, horizonY, x + size * 0.02, horizonY);

        var ax = x + (size * 0.66).toNumber();
        var ah = size * 0.30;
        if (isRise) {
            dc.fillPolygon([
                [ax, y - ah],
                [ax - ah * 0.65, y + ah * 0.45],
                [ax + ah * 0.65, y + ah * 0.45]
            ] as Array<[Numeric, Numeric]>);
        } else {
            dc.fillPolygon([
                [ax, y + ah],
                [ax - ah * 0.65, y - ah * 0.45],
                [ax + ah * 0.65, y - ah * 0.45]
            ] as Array<[Numeric, Numeric]>);
        }
    }

    // Rounded-rectangle "cloud" used as the base of several weather icons.
    // Sizes bumped up from the original ratios - at the small icon sizes
    // the WX row actually renders at, the previous proportions shrank to
    // sub-pixel-radius circles that were effectively invisible.
    // (Not marked private - Monkey C's `module` doesn't support access modifiers on functions, only `class` does.)
    function drawCloudBase(dc as Graphics.Dc, x as Numeric, y as Numeric, size as Numeric, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var r = size * 0.27;
        dc.fillCircle(x - (size * 0.24).toNumber(), y, r);
        dc.fillCircle(x + (size * 0.06).toNumber(), y - (size * 0.14).toNumber(), r * 1.15);
        dc.fillCircle(x + (size * 0.36).toNumber(), y, r * 0.9);
        dc.fillRectangle(x - (size * 0.24).toNumber(), y, (size * 0.62).toNumber(), (r).toNumber());
    }

    function drawWeatherIcon(dc as Graphics.Dc, x as Numeric, y as Numeric, size as Numeric, bucket as Symbol, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);

        if (bucket == :sunny) {
            var r = size * 0.30;
            dc.fillCircle(x, y, r);
            for (var i = 0; i < 8; i++) {
                var ang = i * Math.PI / 4.0;
                var x0 = x + (r * 1.35) * Math.cos(ang);
                var y0 = y + (r * 1.35) * Math.sin(ang);
                var x1 = x + (r * 2.0) * Math.cos(ang);
                var y1 = y + (r * 2.0) * Math.sin(ang);
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

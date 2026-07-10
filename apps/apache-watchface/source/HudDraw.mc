import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Weather;

// Panel/divider chrome (still vector-drawn - no anti-aliasing concerns for
// straight lines/octagon outlines at this stroke width) plus the small
// bitmap-drawing helpers used once the stat-row glyphs (battery, heart,
// boot, solar, weather) moved from live Dc.fillPolygon/fillCircle vector
// icons to pre-rendered, anti-aliased PNG bitmap assets. `size` is the
// icon's target bounding box in pixels.
module HudDraw {

    // V6: the octagon-cut "MFD box" panel outline (drawPanel(), previously
    // called from every draw*Box() method) is gone entirely - client:
    // "remove all the boxes... replace with clean divider lines." Framing
    // is now a thin straight line between field rows/columns, the same
    // "text + flanking line" language drawFooter() already used, rather
    // than a bordered panel per field group.
    const DIVIDER_STROKE_PX = 1;

    // Horizontal divider between two rows. Thin (1px, not the old 2px MFD
    // box stroke) - it's framing, not information, so it should read as a
    // quiet baseline, not compete with field text/icons. Callers pass
    // ColorScheme.panelColor() (renamed conceptually to "divider color" by
    // this change, constant names unchanged) so the dimness-relative-to-
    // text-color role panels always had is preserved.
    function drawHLine(dc as Graphics.Dc, x1 as Float, x2 as Float, y as Float, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(DIVIDER_STROKE_PX);
        dc.drawLine(x1, y, x2, y);
    }

    // Vertical divider between two side-by-side fields in the same row
    // (Battery|HR, Steps|Solar, Date|Timezone2).
    function drawVLine(dc as Graphics.Dc, x as Float, y1 as Float, y2 as Float, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(DIVIDER_STROKE_PX);
        dc.drawLine(x, y1, x, y2);
    }

    // Scales a bitmap into an arbitrary target box, centered on (cx, cy),
    // preserving the bitmap's native aspect ratio (contain-fit, not
    // stretch-fill - stretching would visibly distort the artwork since
    // several target boxes have a different aspect ratio than their
    // source asset, e.g. the AH-64E banner). Null-safe like
    // drawBitmapCentered. Uses Dc.drawScaledBitmap(), confirmed present in
    // this SDK's Graphics.Dc API.
    function drawBitmapScaledCentered(dc as Graphics.Dc, cx as Float, cy as Float, bitmap as Graphics.BitmapType?,
                                       nativeW as Float, nativeH as Float, maxW as Float, maxH as Float) as Void {
        if (bitmap == null) {
            return;
        }
        var scale = maxW / nativeW;
        var scaleH = maxH / nativeH;
        if (scaleH < scale) {
            scale = scaleH;
        }
        var w = nativeW * scale;
        var h = nativeH * scale;
        dc.drawScaledBitmap(cx - (w / 2.0), cy - (h / 2.0), w, h, bitmap);
    }

    // Draws a bitmap centered on (cx, cy), given its native w/h. Bitmaps are
    // fixed-size assets (no runtime scaling - Dc has no anti-aliased scale
    // path), so every caller just needs consistent center-to-top-left
    // conversion math. Null-safe: a bitmap that failed to load (e.g. a
    // resource load ordering bug) is skipped rather than crashing
    // dc.drawBitmap on a null reference.
    function drawBitmapCentered(dc as Graphics.Dc, cx as Numeric, cy as Numeric, bitmap as Graphics.BitmapType?, w as Numeric, h as Numeric) as Void {
        if (bitmap == null) {
            return;
        }
        dc.drawBitmap(cx - (w / 2.0), cy - (h / 2.0), bitmap);
    }

    // The battery chrome bitmap is outline+nub only (no fill baked in, so
    // one asset can represent every charge level) - this draws just the
    // proportional charge fill as a plain rectangle on top of it. Inset
    // generously from the 34x18 bounds so the fill can never spill over the
    // outline stroke or into the nub on the right edge; a discrete-vs-smear
    // pixel-perfect fit isn't the goal here, staying clearly inside the
    // chrome is. (x, y) is the chrome bitmap's top-left corner, matching
    // drawBitmapCentered's/dc.drawBitmap's convention.
    function drawBatteryFill(dc as Graphics.Dc, x as Numeric, y as Numeric, w as Numeric, h as Numeric, percent as Float, color as Number) as Void {
        var insetX = w * 0.15;
        var insetY = h * 0.15;
        var innerLeft = x + insetX;
        var innerTop = y + insetY;
        var innerBottom = y + h - insetY;
        var innerRight = x + (w * 0.78); // stop well clear of the nub, don't need the last 15% back
        var innerW = innerRight - innerLeft;
        var innerH = innerBottom - innerTop;
        if (innerW < 1) {
            innerW = 1;
        }
        if (innerH < 1) {
            innerH = 1;
        }

        var pct = percent / 100.0;
        if (pct < 0) {
            pct = 0;
        }
        if (pct > 1) {
            pct = 1;
        }
        var fillW = innerW * pct;
        if (percent > 0 && fillW < 1) {
            fillW = 1; // always show a sliver rather than nothing at very low charge
        }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(innerLeft, innerTop, fillW, innerH);
    }

    // Maps the (large) Weather.CONDITION_* enum down to the 6 icon buckets
    // the bitmap set provides. Only uses condition constants confirmed
    // present since the Weather module's original 3.1.0 release; extend
    // this list with more CONDITION_* values from the API docs if you want
    // finer distinctions (e.g. separate "flurries" vs "heavy snow" icons).
    function mapConditionToBucket(condition as Number?) as Symbol {
        if (condition == null) {
            return :overcast;
        }

        if (condition == Weather.CONDITION_CLEAR || condition == Weather.CONDITION_FAIR) {
            return :clear;
        }

        if (condition == Weather.CONDITION_PARTLY_CLOUDY || condition == Weather.CONDITION_MOSTLY_CLEAR) {
            return :cloudy;
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

        if (condition == Weather.CONDITION_MOSTLY_CLOUDY
            || condition == Weather.CONDITION_CLOUDY
            || condition == Weather.CONDITION_FOG
            || condition == Weather.CONDITION_HAZY
            || condition == Weather.CONDITION_WINDY
            || condition == Weather.CONDITION_UNKNOWN) {
            return :overcast;
        }

        return :overcast;
    }
}

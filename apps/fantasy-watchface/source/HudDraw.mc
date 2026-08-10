import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Weather;

// Bitmap-drawing helpers: castle-wall tile dividers (replaces apache-
// watchface's plain HudDraw.drawHLine/drawVLine), the mana-potion
// proportional fill (replaces its battery chrome fill), plain bitmap
// centering/scaling, and the weather condition -> icon bucket map (ported
// unchanged - theme-agnostic).
module HudDraw {

    // Native repeat-unit pixel size of the two wall tile assets (see
    // tools/generate_fantasy_icons.py:wall_h()/wall_v()) - tiles are drawn
    // edge-to-edge at exactly this pitch so there's no gap/overlap.
    const WALL_H_W = 14.0;
    const WALL_H_H = 8.0;
    const WALL_V_W = 8.0;
    const WALL_V_H = 14.0;

    // Horizontal divider between two rows, built from repeated wall_h
    // tiles instead of a single drawLine() - "text + castle wall" in place
    // of apache-watchface's "text + plain divider line" language. Tiles
    // from x1 rightward at the tile's native 14px pitch, clamped to never
    // draw a tile that would start past x2 (a partial/overflowing tile is
    // worse than a slightly short run - matches this project's standing
    // "clamp, don't overflow the bezel" convention).
    function drawWallH(dc as Graphics.Dc, x1 as Float, x2 as Float, y as Float, bitmap as Graphics.BitmapType?) as Void {
        if (bitmap == null) {
            return;
        }
        var x = x1;
        while (x + WALL_H_W <= x2 + 0.01) {
            dc.drawBitmap(x, y - (WALL_H_H / 2.0), bitmap);
            x += WALL_H_W;
        }
    }

    // Vertical counterpart - tiles from y1 downward at the tile's native
    // 14px pitch, same clamp-not-overflow convention.
    function drawWallV(dc as Graphics.Dc, x as Float, y1 as Float, y2 as Float, bitmap as Graphics.BitmapType?) as Void {
        if (bitmap == null) {
            return;
        }
        var y = y1;
        while (y + WALL_V_H <= y2 + 0.01) {
            dc.drawBitmap(x - (WALL_V_W / 2.0), y, bitmap);
            y += WALL_V_H;
        }
    }

    // Scales a bitmap into an arbitrary target box, centered on (cx, cy),
    // preserving the bitmap's native aspect ratio (contain-fit, not
    // stretch-fill). Null-safe. Ported unchanged from apache-watchface.
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

    // Draws a bitmap centered on (cx, cy), given its native w/h. Null-safe
    // (a bitmap that failed to load is skipped rather than crashing
    // dc.drawBitmap on a null reference). Ported unchanged.
    function drawBitmapCentered(dc as Graphics.Dc, cx as Numeric, cy as Numeric, bitmap as Graphics.BitmapType?, w as Numeric, h as Numeric) as Void {
        if (bitmap == null) {
            return;
        }
        dc.drawBitmap(cx - (w / 2.0), cy - (h / 2.0), bitmap);
    }

    // The potion_glass bitmap's bulb is outline-only by design (see
    // tools/generate_fantasy_icons.py:potion() - "fill is added
    // dynamically in Monkey C", same pattern as apache-watchface's old
    // battery chrome) - this draws the proportional mana fill inside the
    // bulb's actual inner ellipse bounds, re-derived from the exact
    // fractions the icon generator used (bulb_cx=0.62*W, cy=0.52*H,
    // bulb_rx=0.30*W, bulb_ry=0.44*H on the 34x18 canvas) rather than a
    // plain rounded rect. The fill rect's half-extents are 0.62x the
    // ellipse's own radii - (0.62^2 + 0.62^2) = 0.77 < 1, so every corner
    // of the fill rect is verified to sit strictly inside the ellipse
    // (never crosses the outline stroke), confirmed by a real screenshot
    // at both a forced 0% (1px sliver) and forced 100% (full) charge.
    // (x, y) is the bitmap's top-left corner, matching drawBitmapCentered's
    // convention.
    function drawPotionFill(dc as Graphics.Dc, x as Numeric, y as Numeric, w as Numeric, h as Numeric, percent as Float, color as Number) as Void {
        var bulbCx = x + (w * 0.62);
        var bulbCy = y + (h * 0.52);
        var bulbRx = w * 0.30;
        var bulbRy = h * 0.44;

        var fillRx = bulbRx * 0.62;
        var fillRy = bulbRy * 0.62;
        var innerLeft = bulbCx - fillRx;
        var innerTop = bulbCy - fillRy;
        var innerW = fillRx * 2.0;
        var innerH = fillRy * 2.0;
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
    // the bitmap set provides. Ported unchanged from apache-watchface -
    // theme-agnostic.
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

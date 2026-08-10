import Toybox.Graphics;
import Toybox.Lang;

// The core visual signature of this theme: "etched stone, carved with a
// glowing rune". Monkey C vector fonts have no weight axis, so a literal
// thin/thick font-weight contrast isn't achievable - this is the closest
// achievable approximation, verified by an actual zoomed screenshot of the
// clock (see CLAUDE.md): draw the same text twice, dead-center on the same
// anchor point, once at the field's normal ("stone") size in the stone
// color, then again at a smaller ("rune") size in the rune color. The size
// delta (not a weight delta) is what reads as "a thinner, brighter rune
// peeking through the carved outline" at a glance.
//
// Every text field on this face routes through this one function (see
// Fonts.mc for the paired stone/rune font getters per role) instead of
// duplicating the two-draw pattern at each call site.
module ThemeText {
    function drawDual(dc as Graphics.Dc, x as Numeric, y as Numeric, text as String,
                       stoneFont as Graphics.FontType, runeFont as Graphics.FontType,
                       justify as Number, stoneColor as Number, runeColor as Number) as Void {
        dc.setColor(stoneColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, stoneFont, text, justify);

        dc.setColor(runeColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, runeFont, text, justify);
    }
}

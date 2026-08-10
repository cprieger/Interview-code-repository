import Toybox.Graphics;
import Toybox.Lang;

// "Etched stone that glows with runes" palette - two families, used
// consistently across every icon (see tools/generate_fantasy_icons.py,
// which shares these exact hex values) and every text field (see
// ThemeText.mc's dual-layer draw):
//   STONE - cool silver-grey, the "carved rock" surface (day) / dimmer grey
//           (Always-On)
//   RUNE  - light glowing blue (day) / dim blue (Always-On), the "magic
//           peeking through the carving"
//
// CRITICAL, hard-won this session (see CLAUDE.md for the full story): this
// device's hardware is RGB222 - only 64 real colors total ever exist on the
// physical panel, 4 levels per channel (0/85/170/255). Every hex constant
// below is deliberately chosen to already sit exactly on that grid. A first
// draft of the BACKGROUND bitmap used continuous "nice in Pillow" values
// that were NOT on the grid and got hardware-snapped to something totally
// different (tan parchment rendered bright pink) - confirmed via an actual
// simulator screenshot, not assumed. ANY new color added here later must
// also be built from {0,85,170,255} per channel or it will render as
// something unintended.
module ColorScheme {
    const STONE_DAY = 0xAAAAAA;
    const STONE_DAY_DETAIL = 0x555555;
    const RUNE_DAY = 0x55AAFF;
    const STONE_AOD = 0x555555;
    const RUNE_AOD = 0x0055AA;

    const HEART_RED = 0xAA0000;
    const SOLAR_GOLD = 0xFFAA00;
    const SOLAR_AMBER = 0xFF5500;
    const MANA_BLUE = RUNE_DAY;
    const MANA_BLUE_AOD = RUNE_AOD;

    // Battery-critical alert override (the one dynamic color swap on this
    // face, same "one exception" convention apache-watchface's tactical
    // palette used for its own battery-critical red). Pure grid-safe red -
    // (255,0,0) sits exactly on {0,85,170,255} per channel.
    const ALERT_RED = 0xFF0000;
    const BATTERY_CRITICAL_PCT = 15.0;

    const BACKGROUND = Graphics.COLOR_BLACK;

    // The "stone" layer color for a given mode - the dual-layer text
    // treatment's base/outline draw (see ThemeText.drawDual).
    function stoneColor(isSleeping as Boolean) as Number {
        return isSleeping ? STONE_AOD : STONE_DAY;
    }

    // The "rune" layer color for a given mode - drawn smaller, on top of
    // the stone layer, at the exact same anchor position.
    function runeColor(isSleeping as Boolean) as Number {
        return isSleeping ? RUNE_AOD : RUNE_DAY;
    }

    // Dimmer tone for divider/framing chrome (castle-wall tile icons carry
    // their own baked color, but the couple of vector-drawn accents - e.g.
    // the disconnected-Bluetooth dot - still need a "quieter than text"
    // color reference). AOD can't go dimmer than STONE_AOD without hitting
    // 0/black, which would vanish against the black background - same grid
    // constraint the icon generator's own AOD detail color hit, so AOD's
    // "dim" tier reuses STONE_AOD rather than introducing an invisible
    // fourth tier.
    function dimColor(isSleeping as Boolean) as Number {
        return isSleeping ? STONE_AOD : STONE_DAY_DETAIL;
    }

    function isBatteryCritical(batteryPercent as Numeric) as Boolean {
        return batteryPercent < BATTERY_CRITICAL_PCT;
    }

    // Battery/potion field is the one dynamic override on this face: both
    // dual-layer colors AND the mana fill collapse to a single flat
    // ALERT_RED when charge is critical (a real alert, not decoration -
    // deliberately NOT dual-layered at that point, a flat unmistakable red
    // reads faster than a two-tone glow effect for something urgent).
    function batteryStoneColor(isSleeping as Boolean, batteryPercent as Numeric) as Number {
        return isBatteryCritical(batteryPercent) ? ALERT_RED : stoneColor(isSleeping);
    }

    function batteryRuneColor(isSleeping as Boolean, batteryPercent as Numeric) as Number {
        return isBatteryCritical(batteryPercent) ? ALERT_RED : runeColor(isSleeping);
    }

    function manaFillColor(isSleeping as Boolean, batteryPercent as Numeric) as Number {
        if (isBatteryCritical(batteryPercent)) {
            return ALERT_RED;
        }
        return isSleeping ? MANA_BLUE_AOD : MANA_BLUE;
    }
}

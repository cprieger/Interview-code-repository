import Toybox.Graphics;
import Toybox.Lang;

// Phosphor-green LCD palette. Day and Always-On are both single-hue green
// (this design is inherently "monochrome" by construction) - the only
// difference is that day mode carries two small accent hues (amber for
// solar, red for heart) that Always-On desaturates down to the same green
// as everything else, per the spec's "Always-On = monochrome" requirement.
// MIP displays don't expose named accent constants for these hues, so
// they're given as raw 0xRRGGBB literals - the firmware quantizes to the
// nearest of the display's 64 palette colors.
module ColorScheme {
    const PHOSPHOR = 0x8CFF6E;      // primary text/icon green
    const PHOSPHOR_DIM = 0x3E6B38;  // panel outlines, dividers, chapter ring
    const AMBER = 0xF2D33C;         // day-mode solar accent only
    const RED = 0xE05A4E;           // day-mode heart accent only

    const BACKGROUND = Graphics.COLOR_BLACK;

    // Day mode (awake, full color)
    const DAY_TEXT = PHOSPHOR;
    const DAY_ACCENT = PHOSPHOR;
    const DAY_SOLAR = AMBER;
    const DAY_HEART = RED;

    // Always-On mode (sleeping) - desaturated to a single dim green
    const AOD_TEXT = 0x5FA855;
    const AOD_ACCENT = 0x5FA855;
    const AOD_SOLAR = 0x5FA855;
    const AOD_HEART = 0x5FA855;

    function textColor(isSleeping as Boolean) as Number {
        return isSleeping ? AOD_TEXT : DAY_TEXT;
    }

    function accentColor(isSleeping as Boolean) as Number {
        return isSleeping ? AOD_ACCENT : DAY_ACCENT;
    }

    function solarColor(isSleeping as Boolean) as Number {
        return isSleeping ? AOD_SOLAR : DAY_SOLAR;
    }

    function heartColor(isSleeping as Boolean) as Number {
        return isSleeping ? AOD_HEART : DAY_HEART;
    }

    // Panel outlines, dividers, and the chapter ring stay dim in both
    // modes - they're framing, not information, so they never compete
    // with the text/icons for attention.
    function panelColor(isSleeping as Boolean) as Number {
        return PHOSPHOR_DIM;
    }
}

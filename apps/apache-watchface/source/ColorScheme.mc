import Toybox.Graphics;

// Color palette for day mode vs. Always-On (low power / sleeping) mode.
// MIP displays don't expose a named "cyan" Graphics.COLOR_* constant, so
// accent colors are given as raw 0xRRGGBB literals — the firmware quantizes
// these to the nearest of the display's 64 palette colors.
module ColorScheme {
    const CYAN = 0x00E5FF;
    const YELLOW = 0xFFE100;
    const RED = 0xFF3B30;

    const BACKGROUND = Graphics.COLOR_BLACK;

    // Day mode (awake, full color)
    const DAY_TEXT = Graphics.COLOR_WHITE;
    const DAY_ACCENT = CYAN;
    const DAY_SOLAR = YELLOW;
    const DAY_HEART = RED;

    // Always-On mode (sleeping, monochrome to save power)
    const AOD_TEXT = Graphics.COLOR_WHITE;
    const AOD_ACCENT = Graphics.COLOR_LT_GRAY;
    const AOD_SOLAR = Graphics.COLOR_LT_GRAY;
    const AOD_HEART = Graphics.COLOR_LT_GRAY;

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
}

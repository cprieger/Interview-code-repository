import Toybox.Graphics;
import Toybox.Lang;

// V2 spec: Monochromatic Tactical Green against pitch black is the default
// for EVERY field, in both day and Always-On mode - there is no longer a
// per-field amber (solar) or red (heart) accent hue like V1 had. The ONLY
// exception is a dynamic override: the battery field's drawing color swaps
// to Tactical Alert Red whenever charge drops below BATTERY_CRITICAL_PCT.
// Every other field (heart, solar, steps, weather, date, clock, chrome)
// always uses the same flat green in a given mode - "monochrome by
// construction," not "monochrome except for two baked-in accent colors"
// like the old PHOSPHOR/AMBER/RED trio.
//
// Always-On still gets its own dimmer variant of the same hue (not a
// different hue) so the "Always-On = monochrome" spec requirement and the
// "single hue for everything" V2 requirement both hold at once.
module ColorScheme {
    const TACTICAL_GREEN = 0x39FF14;   // day-mode primary color - text, icons, vector chrome

    // V6: client - "brighten everything, especially Always-On/offline
    // mode." The old 0x1B7A0A was ~2.1x dimmer than TACTICAL_GREEN channel-
    // for-channel, which (sRGB gamma is non-linear) reads as roughly a 5x
    // *perceptual* brightness drop, not a 2x one - genuinely "quite dim."
    // Raised to a flat 2/3 scale of TACTICAL_GREEN's R/G/B (0x26AA0D) -
    // still legibly dimmer than day mode (so Always-On stays visually
    // distinct at a glance, per spec) but far less crushed.
    const AOD_GREEN = 0x26AA0D;        // dimmed monochrome variant for Always-On
    const ALERT_RED = 0xFF1E1E;        // Tactical Alert Red - battery-critical override ONLY

    const BACKGROUND = Graphics.COLOR_BLACK;

    const BATTERY_CRITICAL_PCT = 15.0;

    // V6: these are now DIVIDER LINE colors (HudDraw.drawHLine/drawVLine),
    // not box-outline colors - the octagon "MFD box" panels are gone (see
    // HudDraw.mc). Raised alongside AOD_GREEN above ("everything should
    // read brighter overall") but kept well below textColor() in both
    // modes - dividers are framing, not information, and must never
    // compete with field text/icons for attention.
    const PANEL_DAY = 0x1F8C0B;
    const PANEL_AOD = 0x155E07;

    function textColor(isSleeping as Boolean) as Number {
        return isSleeping ? AOD_GREEN : TACTICAL_GREEN;
    }

    // Icons/accents no longer get their own hue (heart and solar go back to
    // plain green per spec) - accentColor is just an alias of textColor now,
    // kept as its own function so call sites that conceptually want "the
    // live-data highlight color" don't need to change if that ever splits
    // again later.
    function accentColor(isSleeping as Boolean) as Number {
        return textColor(isSleeping);
    }

    function panelColor(isSleeping as Boolean) as Number {
        return isSleeping ? PANEL_AOD : PANEL_DAY;
    }

    // The ONLY field-level color override in the whole face: battery text,
    // fill, and box border all swap to Tactical Alert Red below the
    // critical threshold, in both day and Always-On mode. (MIP displays
    // cost the same to redraw regardless of color, so there's no
    // battery-optimization reason to suppress the alert color in
    // Always-On - critical charge is exactly the kind of thing worth
    // surfacing even while asleep.)
    function batteryColor(isSleeping as Boolean, batteryPercent as Numeric) as Number {
        if (batteryPercent < BATTERY_CRITICAL_PCT) {
            return ALERT_RED;
        }
        return textColor(isSleeping);
    }

    function isBatteryCritical(batteryPercent as Numeric) as Boolean {
        return batteryPercent < BATTERY_CRITICAL_PCT;
    }
}

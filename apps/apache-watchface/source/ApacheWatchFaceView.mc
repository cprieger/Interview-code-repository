import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.ActivityMonitor;
import Toybox.Application.Properties;

// V6: store-publishable pass, branched fresh off main (not more commits on
// the old add-apache-watchface branch, per this app's own versioning
// convention). Four changes on top of the V2.1-era matrix documented
// below:
//   1. All octagon "MFD box" panel outlines (HudDraw.drawPanel()) are
//      gone - replaced by thin divider lines (HudDraw.drawHLine/drawVLine)
//      in the same "text + flanking line" language drawFooter() already
//      used. See the new "V6 pixel coordinate matrix" comment block below
//      for the reworked row layout this enabled.
//   2. Clock got noticeably bigger (Fonts.timeFont() 37->44px, box H
//      72->84) - the room came from tightening the box-border padding
//      that's no longer needed between rows into flat 4px gaps, not from
//      any new vertical territory (the total title-to-footer band is
//      still ~262px, same budget as V2.1).
//   3. A new Timezone 2 field sits beside the date (task 4) - user-
//      configurable zone picker + manual US DST math, see TzCalc.mc, since
//      Connect IQ has no public API for the watch's native "Time Zone 2"
//      setting.
//   4. Airframe (top banner) and squad (footer) text are now
//      `alphaNumeric` string properties instead of a hardcoded string /
//      baked bitmap - editable per-soldier via Garmin Connect Mobile, no
//      recompile, since this is heading toward a public listing rather
//      than one client's sideload.
//
// V2: fixed pixel coordinate matrix for the real 280x280 fenix7xpro panel
// (center 140,140 / bezel radius 140) - replaces V1's dynamic
// safeHalfWidth()/circle-geometry row layout with the client's literal
// per-field boxes.
//
// V2.1 client feedback (real screenshot): text overlapping/unclear. Redid
// every box's corner-distance math against the true 140px bezel radius
// (worst corner = sqrt(max(|left-cx|,|right-cx|)^2 + max(|top-cy|,|bottom-cy|)^2))
// instead of eyeballing, and found the V2 literal spec numbers put THREE
// boxes' corners genuinely outside/at the visible circle, not just tight:
// Battery/HR corner was ~161px from center (21px past the 140px edge),
// Date's bottom corners were ~153px (13px past), Steps/Solar/Weather/Title
// were all within ~0-1.4px of the edge (effectively zero margin). That's
// a real source of the "overlapping/unclear" complaint - box borders and
// text were being cut by the round bezel mask, not just crowded.
//
// Every box below was resized/repositioned to a verified >=6px corner
// margin from the true edge (most land at 8-13px), narrowing width being
// the main lever (frees far more margin per pixel than moving vertically,
// since horizontal offset and vertical offset both feed the same corner
// dist formula, and rows this close to the top/bottom already spend most
// of their radius budget on the vertical term). Real geometry/render
// limits found in the process, all honored rather than argued with:
//   - The title banner and Weather box sit so close to the top/bottom pole
//     of the circle that "push up/down AND stay margin-safe" trade off
//     directly - narrowing bought far more safety per pixel than moving
//     vertically did, so the title mostly got narrower with only a small
//     (2px) up-nudge, not a dramatic one.
//   - A real screenshot of an initial Weather-box "push down" (Y=252)
//     showed the Footer text below it rendering visibly dim/soft compared
//     to every other field on the exact same font - the round display's
//     physical edge curvature/mask softens content in roughly the last
//     15px of radius regardless of what the literal square-canvas corner
//     math says, and that isn't captured by the formula above. Both boxes
//     were pulled back toward center instead (Weather net 2px UP from
//     V2's original position, Footer 2px up from V2's), prioritizing an
//     actually-legible result over the literal direction of the nudge.
//   - The Solar box's "NEXT SOLAR" label overflowed past its own right
//     border once the box was narrowed - caught in the same screenshot,
//     fixed by shortening the label to "SOLAR" (matches the terseness of
//     every other box label: PWR/HR/STP) rather than widening the box
//     back out.
// Removing the outer chapter-ring tick gauge (dead code, gone from
// HudDraw.mc/onUpdate() - client called it "the weird ring around the
// edge") didn't directly free pixels for these boxes (the ring was a
// background layer other boxes already drew over), but it does mean the
// outer band of the face is no longer visually competing with tick marks,
// so the added vertical gap around the clock (top row -> clock gap grew
// 6px -> 12px) actually reads as breathing room instead of clutter.
class ApacheWatchFaceView extends WatchUi.WatchFace {
    private const DAY_ABBREV as Array<String> = ["", "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];

    // Native bitmap pixel dimensions - fixed-size assets, sized/positioned
    // by the box layout below rather than scaled at runtime (except where
    // a box is explicitly too small for the native asset - Weather/BT/Bell
    // use HudDraw.drawBitmapScaledCentered() for that reason, noted at
    // their call sites).
    private const BATTERY_W = 34.0;
    private const BATTERY_H = 18.0;
    private const HEART_W = 28.0;
    // V6: client - heart icon "touches the bottom of its field." Trimmed
    // 1px (28 -> 27) per the client's own suggested first try.
    private const HEART_H = 27.0;
    private const BOOT_W = 36.0;
    // Grew 24->32: boot icon now includes an ankle shaft on top
    // (client: "give it like a little top to the boot").
    private const BOOT_H = 32.0;
    // Native bitmap resolution - NOT the on-screen display size (see
    // SOLAR_DISPLAY_SIZE below). A first V5 attempt just changed this
    // constant and used drawBitmapCentered() (which only centers, it
    // doesn't scale) - a forced worst-case screenshot showed the icon
    // still rendering at its full native 28px and still colliding with
    // the time text. Fixed by actually scaling via
    // drawBitmapScaledCentered() instead.
    private const SOLAR_W = 28.0;
    private const SOLAR_H = 28.0;
    // V5: client - icon/time were colliding. Actual on-screen size,
    // scaled down from the 28px native asset. First try at 20px still
    // looked tight in a zoomed screenshot check - dropped to 17px for
    // real breathing room instead of leaving it borderline.
    private const SOLAR_DISPLAY_SIZE = 17.0;
    private const WX_W = 32.0;
    private const WX_H = 32.0;
    private const BT_W = 22.0;
    private const BT_H = 22.0;
    private const BELL_W = 24.0;
    private const BELL_H = 24.0;

    // V3: Bluetooth/bell status icons moved from flanking the Weather box to
    // flanking the Battery/HR row instead (client: "It should be to the left
    // and right of the battery and heart where there is that little cut
    // out."). Sized up from the old 12px (that row only had ~38px of slack
    // per side) now that this row has ~30-45px of slack per side depending on
    // Y - see drawStatusFlanking() for the actual margin verification.
    private const STATUS_ICON_SIZE = 14.0;
    private const STATUS_ICON_GAP = 2.0; // clearance from the Battery/HR box edge

    // ---- V6 pixel coordinate matrix ----
    // Boxes are gone (see HudDraw.mc); these are now just content anchors
    // plus divider-line positions. Every position below was re-verified
    // against the real 140px bezel radius using the same corner-distance
    // formula this file has used since V2.1:
    //   worst_corner_dist = sqrt(max(|left-cx|,|right-cx|)^2 + max(|top-cy|,|bottom-cy|)^2)
    // against center (140,140), required < 140 with >=6px margin. Removing
    // the box borders/chamfer padding didn't free much *vertical* budget
    // directly (the total usable band, title-top to footer-bottom, is
    // still ~262px, same as V2.1) - what it did free is the padding that
    // used to be reserved for box strokes/chamfers between rows, which was
    // reallocated as a straight 4px row-to-row gap (with a 1px divider
    // line at its midpoint) instead, and the clock box got the single
    // biggest reallocation (+12px height) since a bigger clock was the
    // explicit ask (task 3).
    //
    // Every row's margin was recomputed for its NEW Y position, not
    // assumed to carry over from V2.1 - several rows shifted a few px and
    // needed a fresh check (Steps/Solar's margin tightened 13.5->11.8px
    // from shifting down 5px, Date/Tz2's combined two-field row is the
    // tightest new margin at ~7.9px, both still comfortably >=6px).
    private const TITLE_CX = 140.0;
    private const TITLE_BOX_Y = 12.0;
    private const TITLE_BOX_H = 14.0;
    // Bezel-safe cap on the title flourish's outer half-width at this row
    // (dy=121 from center at Y=19 => max dx ~57.6px for a 6px margin) -
    // used to clamp/skip the flanking lines instead of ever overflowing
    // the top pole, regardless of how long the user's airframe string is.
    private const TITLE_MAX_HALF_W = 52.0;

    // V6 follow-up: client screenshot showed this row crowding the title
    // text right above it (title bottom ~Y=26 vs. this row's old Y=28 -
    // ~2px gap). Row nudged down 5px for real breathing room under the
    // title; see DIV1_Y below for how far the divider that follows this
    // row could actually move without landing on the clock box.
    private const BATT_BOX_X = 70.0;
    private const BATT_BOX_Y = 33.0;
    private const BATT_BOX_W = 64.0;
    private const BATT_BOX_H = 44.0;

    private const HR_BOX_X = 146.0;
    private const HR_BOX_Y = 33.0;
    private const HR_BOX_W = 64.0;
    // No HR_BOX_H: the row's height is BATT_BOX_H (both fields share the
    // same row) - HR_BOX_H was only ever read by the now-deleted
    // HudDraw.drawPanel() call, keeping a second unused copy of the same
    // 44.0 value around after box removal would just be dead code.

    // Divider under the Battery/HR row, and the vertical divider between
    // them in the natural 12px gap (134..146) the two fields already left.
    // V6 follow-up: shifted down with the row above (75->80) so the row
    // and its divider move as a unit. This lands the divider's constant
    // Y=80 1px past CLOCK_BOX_Y=79's nominal top edge - checked for a real
    // visual collision (not just the constants) via screenshot: the clock's
    // actual rendered digits sit far below that nominal box top (centered
    // at CLOCK_BOX_Y + CLOCK_BOX_H/2 = 121, glyphs spanning roughly
    // 99-143), so there's no visible overlap with the divider line at Y=80
    // - confirmed clean, no need to cascade a clock-box shift (and the
    // matrix rows below it) for a collision that doesn't actually render.
    private const DIV1_Y = 80.0;
    private const DIV1_X1 = 66.0;
    private const DIV1_X2 = 214.0;
    private const DIV_BATTHR_X = 140.0;
    private const DIV_BATTHR_Y1 = 37.0;
    private const DIV_BATTHR_Y2 = 73.0;

    // Clock: the one field explicitly asked to get noticeably bigger (task
    // 3). H grew 72->84 (the main lever - see Fonts.timeFont(), 37->44px)
    // and it stayed centered on X=140 with the same 224px width (a wider
    // box wasn't the bottleneck - see the margin note above, ~239px is the
    // real bezel-safe ceiling here, not much more room than 224 already
    // had). Re-verified against a forced "88:88" + 2-digit-seconds
    // worst-case screenshot per this project's standing doctrine.
    private const CLOCK_BOX_X = 28.0;
    private const CLOCK_BOX_Y = 79.0;
    private const CLOCK_BOX_W = 224.0;
    private const CLOCK_BOX_H = 84.0;

    private const DIV2_Y = 167.0;
    private const DIV2_X1 = 40.0;
    private const DIV2_X2 = 240.0;

    private const STEPS_BOX_X = 36.0;
    private const STEPS_BOX_Y = 171.0;
    private const STEPS_BOX_W = 114.0;
    private const STEPS_BOX_H = 44.0;

    private const SOLAR_BOX_X = 156.0;
    private const SOLAR_BOX_Y = 171.0;
    private const SOLAR_BOX_W = 88.0;
    private const SOLAR_BOX_H = 44.0;

    private const DIV_STEPSSOLAR_X = 153.0;
    private const DIV_STEPSSOLAR_Y1 = 175.0;
    private const DIV_STEPSSOLAR_Y2 = 211.0;
    private const DIV3_Y = 218.0;
    private const DIV3_X1 = 36.0;
    private const DIV3_X2 = 244.0;

    // Date + Timezone2 now share one row (task 4), split by a thin vertical
    // divider instead of a second box. Combined row margin is the
    // tightest new number in this matrix (~7.9px at dy=102, both fields'
    // outer edges land at dx=84 <= the ~86.9px ceiling for a 6px margin) -
    // verified, not assumed, since this is a brand-new two-field row.
    private const DATE_BOX_X = 56.0;
    private const DATE_BOX_Y = 222.0;
    private const DATE_BOX_W = 80.0;
    private const DATE_BOX_H = 20.0;

    private const TZ2_BOX_X = 144.0;
    private const TZ2_BOX_Y = 222.0;
    private const TZ2_BOX_W = 80.0;
    private const TZ2_BOX_H = 20.0;

    private const DIV_DATETZ2_X = 140.0;
    private const DIV_DATETZ2_Y1 = 224.0;
    private const DIV_DATETZ2_Y2 = 240.0;
    private const DIV4_Y = 244.0;
    private const DIV4_X1 = 60.0;
    private const DIV4_X2 = 220.0;

    // Weather: gained back 2px of height (16->18) versus a first-pass
    // matrix, by tightening the Date/Tz2->Weather gap to 4px (matches
    // every other row-to-row gap in this matrix) instead of leaving 6.
    private const WX_BOX_X = 96.0;
    private const WX_BOX_Y = 246.0;
    private const WX_BOX_W = 88.0;
    private const WX_BOX_H = 18.0;

    // Footer position is UNCHANGED from V2.2/V5 - this Y was already
    // real-screenshot-verified as the safe floor near the bottom pole (the
    // round display's edge curvature softens content in the last ~15px of
    // radius regardless of what corner-distance math alone says - see the
    // V2.1 notes still above on the older constants this replaced). No
    // reason to gamble that margin for a box-removal pass that doesn't
    // need it.
    private const FOOTER_CX = 140.0;
    private const FOOTER_Y = 266.0;
    private const FOOTER_H = 8.0;
    // Bezel-safe cap on the footer flourish's outer half-width (dy=126 at
    // Y=270 => max dx ~45.6px for a 6px margin) - tighter than the title's
    // cap since the bottom pole row sits closer to the true edge.
    private const FOOTER_MAX_HALF_W = 42.0;

    private var _cache as DataCache;
    private var _isSleeping as Boolean = false;
    private var _iconsLoaded as Boolean = false;

    // Day/Always-On bitmap pairs, loaded once (see loadIcons()) and cached
    // here rather than reloaded on every onUpdate() call.
    private var _iconBatteryChromeDay as Graphics.BitmapType?;
    private var _iconBatteryChromeAod as Graphics.BitmapType?;
    private var _iconHeartDay as Graphics.BitmapType?;
    private var _iconHeartAod as Graphics.BitmapType?;
    private var _iconBootDay as Graphics.BitmapType?;
    private var _iconBootAod as Graphics.BitmapType?;
    private var _iconSolarRiseDay as Graphics.BitmapType?;
    private var _iconSolarSetDay as Graphics.BitmapType?;
    private var _iconSolarRiseAod as Graphics.BitmapType?;
    private var _iconSolarSetAod as Graphics.BitmapType?;
    private var _iconWxClearDay as Graphics.BitmapType?;
    private var _iconWxCloudyDay as Graphics.BitmapType?;
    private var _iconWxOvercastDay as Graphics.BitmapType?;
    private var _iconWxRainDay as Graphics.BitmapType?;
    private var _iconWxSnowDay as Graphics.BitmapType?;
    private var _iconWxStormDay as Graphics.BitmapType?;
    private var _iconWxClearAod as Graphics.BitmapType?;
    private var _iconWxOvercastAod as Graphics.BitmapType?;
    private var _iconBluetoothDay as Graphics.BitmapType?;
    private var _iconBluetoothAod as Graphics.BitmapType?;
    private var _iconBellDay as Graphics.BitmapType?;
    private var _iconBellAod as Graphics.BitmapType?;

    function initialize() {
        WatchFace.initialize();
        _cache = new DataCache();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        loadIcons();
    }

    // Loads every HUD bitmap resource exactly once. Called from onLayout()
    // (guaranteed to run before the first onUpdate()); guarded by
    // _iconsLoaded in case the system ever calls onLayout() more than once,
    // so resources are never redundantly reloaded.
    private function loadIcons() as Void {
        if (_iconsLoaded) {
            return;
        }

        _iconBatteryChromeDay = WatchUi.loadResource(Rez.Drawables.IconBatteryChromeDay) as Graphics.BitmapType;
        _iconBatteryChromeAod = WatchUi.loadResource(Rez.Drawables.IconBatteryChromeAod) as Graphics.BitmapType;

        _iconHeartDay = WatchUi.loadResource(Rez.Drawables.IconHeartDay) as Graphics.BitmapType;
        _iconHeartAod = WatchUi.loadResource(Rez.Drawables.IconHeartAod) as Graphics.BitmapType;

        _iconBootDay = WatchUi.loadResource(Rez.Drawables.IconBootDay) as Graphics.BitmapType;
        _iconBootAod = WatchUi.loadResource(Rez.Drawables.IconBootAod) as Graphics.BitmapType;

        _iconSolarRiseDay = WatchUi.loadResource(Rez.Drawables.IconSolarRiseDay) as Graphics.BitmapType;
        _iconSolarSetDay = WatchUi.loadResource(Rez.Drawables.IconSolarSetDay) as Graphics.BitmapType;
        _iconSolarRiseAod = WatchUi.loadResource(Rez.Drawables.IconSolarRiseAod) as Graphics.BitmapType;
        _iconSolarSetAod = WatchUi.loadResource(Rez.Drawables.IconSolarSetAod) as Graphics.BitmapType;

        _iconWxClearDay = WatchUi.loadResource(Rez.Drawables.IconWxClearDay) as Graphics.BitmapType;
        _iconWxCloudyDay = WatchUi.loadResource(Rez.Drawables.IconWxCloudyDay) as Graphics.BitmapType;
        _iconWxOvercastDay = WatchUi.loadResource(Rez.Drawables.IconWxOvercastDay) as Graphics.BitmapType;
        _iconWxRainDay = WatchUi.loadResource(Rez.Drawables.IconWxRainDay) as Graphics.BitmapType;
        _iconWxSnowDay = WatchUi.loadResource(Rez.Drawables.IconWxSnowDay) as Graphics.BitmapType;
        _iconWxStormDay = WatchUi.loadResource(Rez.Drawables.IconWxStormDay) as Graphics.BitmapType;
        _iconWxClearAod = WatchUi.loadResource(Rez.Drawables.IconWxClearAod) as Graphics.BitmapType;
        _iconWxOvercastAod = WatchUi.loadResource(Rez.Drawables.IconWxOvercastAod) as Graphics.BitmapType;

        _iconBluetoothDay = WatchUi.loadResource(Rez.Drawables.IconBluetoothDay) as Graphics.BitmapType;
        _iconBluetoothAod = WatchUi.loadResource(Rez.Drawables.IconBluetoothAod) as Graphics.BitmapType;
        _iconBellDay = WatchUi.loadResource(Rez.Drawables.IconBellDay) as Graphics.BitmapType;
        _iconBellAod = WatchUi.loadResource(Rez.Drawables.IconBellAod) as Graphics.BitmapType;

        _iconsLoaded = true;
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

    // No onPartialUpdate() override: seconds (the one per-second element)
    // are hidden in Always-On mode, so there's nothing that needs a
    // per-second redraw while sleeping - the system's default low-power
    // fallback of calling onUpdate() once a minute is exactly right here,
    // for free. The V2.1 margin/spacing rework doesn't change this.
    function onUpdate(dc as Graphics.Dc) as Void {
        _cache.refresh(_isSleeping);

        dc.setColor(Graphics.COLOR_WHITE, ColorScheme.BACKGROUND);
        dc.clear();

        var textColor = ColorScheme.textColor(_isSleeping);
        var panelColor = ColorScheme.panelColor(_isSleeping);

        if (!_isSleeping) {
            drawTitleBanner(dc, textColor);
        }

        var battery = System.getSystemStats().battery;
        var battColor = ColorScheme.batteryColor(_isSleeping, battery);
        drawBatteryBox(dc, battery, battColor);
        drawHeartRateBox(dc, textColor);
        // V3: BT/bell moved here from the Weather box - see drawStatusFlanking().
        drawStatusFlanking(dc, textColor, panelColor);

        // V6: boxes are gone - divider lines take their place (task 1).
        // Battery/HR row: horizontal divider below, vertical divider
        // between the two fields in their natural 12px gap.
        HudDraw.drawHLine(dc, DIV1_X1, DIV1_X2, DIV1_Y, panelColor);
        HudDraw.drawVLine(dc, DIV_BATTHR_X, DIV_BATTHR_Y1, DIV_BATTHR_Y2, panelColor);

        drawClockBox(dc, textColor);

        HudDraw.drawHLine(dc, DIV2_X1, DIV2_X2, DIV2_Y, panelColor);

        drawStepsBox(dc, textColor);
        drawSolarBox(dc, textColor);
        HudDraw.drawVLine(dc, DIV_STEPSSOLAR_X, DIV_STEPSSOLAR_Y1, DIV_STEPSSOLAR_Y2, panelColor);
        HudDraw.drawHLine(dc, DIV3_X1, DIV3_X2, DIV3_Y, panelColor);

        drawDateBox(dc, textColor);
        drawTz2Box(dc, textColor);
        HudDraw.drawVLine(dc, DIV_DATETZ2_X, DIV_DATETZ2_Y1, DIV_DATETZ2_Y2, panelColor);
        HudDraw.drawHLine(dc, DIV4_X1, DIV4_X2, DIV4_Y, panelColor);

        drawWeatherBox(dc, textColor);

        drawFooter(dc, textColor);
    }

    // V6: the AH-64E title banner was a baked bitmap (Rez.Drawables.
    // BannerAh64e, a Python-generated PNG with the literal text "AH-64E"
    // and flanking wing-feather artwork) - can't reflect a user-editable
    // string, so it's gone. Replaced with live vector text
    // (Fonts.headerFont(), the existing FACE_STENCIL/leagueGothic header
    // face) reading the new `airframe` string property (default "AH-64E"),
    // plus a small flanking-line flourish in the same language
    // drawFooter() already uses - simplified rather than trying to keep
    // bitmap wing art with a now-configurable string baked into it.
    // Day-mode only (pure decoration, doesn't survive into Always-On) -
    // unchanged from before.
    //
    // Length is defensively clamped (not just relying on the settings.xml
    // maxLength) and the flourish is capped/skipped against
    // TITLE_MAX_HALF_W so a long user-supplied name can never push this
    // row's content past the bezel-safe half-width at this tight,
    // near-top-pole Y - verified against a forced worst-case string.
    private function drawTitleBanner(dc as Graphics.Dc, textColor as Number) as Void {
        var airframe = Properties.getValue("airframe") as String?;
        if (airframe == null || airframe.length() == 0) {
            airframe = "AH-64E";
        }
        if (airframe.length() > 10) {
            airframe = airframe.substring(0, 10);
        }

        var font = Fonts.headerFont();
        var cy = TITLE_BOX_Y + (TITLE_BOX_H / 2.0);
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(TITLE_CX, cy, font, airframe, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var dims = dc.getTextDimensions(airframe, font);
        var halfW = dims[0] / 2.0;
        var inner = halfW + 4.0;
        var outer = inner + 8.0;
        if (outer > TITLE_MAX_HALF_W) {
            outer = TITLE_MAX_HALF_W;
        }
        if (outer > inner) {
            dc.drawLine(TITLE_CX - outer, cy, TITLE_CX - inner, cy);
            dc.drawLine(TITLE_CX + inner, cy, TITLE_CX + outer, cy);
        }
    }

    // Battery box is the one field whose color can dynamically swap to
    // Tactical Alert Red (see ColorScheme.batteryColor) - border, fill
    // rect, label, and value text all use battColor so a critical charge
    // reads unmistakably at a glance. The chrome outline+nub bitmap itself
    // stays baked-in green (no runtime bitmap tint API - same constraint
    // V1 had), so only the vector-drawn parts of the box actually turn
    // red; the assembled box still reads clearly as an alert.
    // Client polish pass: "PWR" text label removed - the battery icon
    // itself (chrome + proportional fill) now sits up where the label
    // used to be (BATT_BOX_Y+14 vs. the label's old +2, roughly the same
    // top region of the box) and serves as the visual label. The percent
    // value moves to its own centered row underneath (BATT_BOX_Y+34, near
    // the box's bottom), so icon and value read as two clearly separated
    // rows instead of a label+icon+value crowded into one.
    private function drawBatteryBox(dc as Graphics.Dc, battery as Float, battColor as Number) as Void {
        var iconCX = BATT_BOX_X + (BATT_BOX_W / 2.0);
        var iconCY = BATT_BOX_Y + 13.0; // client: "move the battery up 1 pixel" (was +14)
        var battChrome = _isSleeping ? _iconBatteryChromeAod : _iconBatteryChromeDay;
        HudDraw.drawBitmapCentered(dc, iconCX, iconCY, battChrome, BATTERY_W, BATTERY_H);
        HudDraw.drawBatteryFill(dc, iconCX - (BATTERY_W / 2.0), iconCY - (BATTERY_H / 2.0), BATTERY_W, BATTERY_H, battery, battColor);

        var valueCY = BATT_BOX_Y + 34.0;
        dc.setColor(battColor, Graphics.COLOR_TRANSPARENT);
        // client: "reduce the font of the battery number by 1" - dedicated
        // batteryValueFont(), scoped to just this field.
        var battValueText = battery.format("%d") + "%";
        dc.drawText(iconCX, valueCY, Fonts.batteryValueFont(), battValueText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Client: "HR" text label removed, heart icon lifted up to roughly
    // where the label used to sit - the same icon-on-top/value-below
    // structure the battery box already uses (this also resolves the
    // visual inconsistency flagged after that pass: both boxes now match).
    private function drawHeartRateBox(dc as Graphics.Dc, textColor as Number) as Void {
        var iconCX = HR_BOX_X + (HR_BOX_W / 2.0);
        var iconCY = HR_BOX_Y + 14.0;
        var heartIcon = _isSleeping ? _iconHeartAod : _iconHeartDay;
        HudDraw.drawBitmapCentered(dc, iconCX, iconCY, heartIcon, HEART_W, HEART_H);

        var hr = _cache.heartRate;
        var hrText = (hr != null) ? hr.toString() : "--";
        var valueCY = HR_BOX_Y + 34.0;
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(iconCX, valueCY, Fonts.metricsFont(), hrText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // V3: client - "it occasionally touches the second hand" (the seconds
    // readout, not an analog hand - this is a digital face). Root cause:
    // timeFont/secFont are Graphics.getVectorFont() faces (sourceSansPro),
    // which are proportional, not monospace - timeStr's measured width
    // varies with which digits are showing (e.g. "11:11" is narrower than
    // "18:08"). secX is normally the measured right edge of timeStr + a
    // fixed 6px gap, which is correctly adaptive - but it's clamped to
    // maxSecX (the box's right inner edge) so seconds never overflow the
    // panel. For a wide timeStr, the adaptive secX can exceed maxSecX, so
    // the clamp pulls seconds back left toward/into timeStr's own right
    // edge - the actual source of the "touches" complaint, not a fixed
    // shortfall that a bigger gap constant would fix.
    //
    // Client, precise correction over the earlier guess: "move the hours
    // and minutes over 5 pixels to the left. Then leave the seconds where
    // they are." So: timeStr's anchor shifts 5px left of true box center;
    // seconds keep being computed from the ORIGINAL unshifted boxCX (not
    // timeCX) - only the HH:MM group moves, which by itself opens up 5px
    // of extra clearance to the seconds readout for every digit
    // combination, without needing to touch where seconds themselves land.
    private const TIME_ANCHOR_SHIFT_PX = 5.0;

    private function drawClockBox(dc as Graphics.Dc, textColor as Number) as Void {
        var boxCX = CLOCK_BOX_X + (CLOCK_BOX_W / 2.0);
        var cy = CLOCK_BOX_Y + (CLOCK_BOX_H / 2.0);
        var timeCX = boxCX - TIME_ANCHOR_SHIFT_PX;

        // Always 24-hour, regardless of device settings - client asked for
        // this explicitly, same as V1.
        var clockTime = System.getClockTime();
        var timeStr = Lang.format("$1$:$2$", [clockTime.hour.format("%02d"), clockTime.min.format("%02d")]);

        var timeFont = Fonts.timeFont();
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(timeCX, cy, timeFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (!_isSleeping) {
            // Seconds position is computed from boxCX (the original,
            // unshifted center) exactly as before this pass - "leave the
            // seconds where they are." Only timeCX (above) moved.
            var timeDims = dc.getTextDimensions(timeStr, timeFont);
            var secFont = Fonts.secondsFont();
            var secStr = clockTime.sec.format("%02d");
            var secDims = dc.getTextDimensions(secStr, secFont);

            var secX = boxCX + (timeDims[0] / 2.0) + 6.0;
            var maxSecX = CLOCK_BOX_X + CLOCK_BOX_W - 6.0 - secDims[0];
            if (secX > maxSecX) {
                secX = maxSecX;
            }

            dc.drawText(secX, cy + (timeDims[1] * 0.18), secFont, secStr,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function drawStepsBox(dc as Graphics.Dc, textColor as Number) as Void {
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        // client: "move the STP over to be centered as well"
        dc.drawText(STEPS_BOX_X + (STEPS_BOX_W / 2.0), STEPS_BOX_Y + 2.0, Fonts.labelsFont(), "STP",
            Graphics.TEXT_JUSTIFY_CENTER);

        var contentY = STEPS_BOX_Y + (STEPS_BOX_H * 0.66);
        var bootIcon = _isSleeping ? _iconBootAod : _iconBootDay;
        var iconCX = STEPS_BOX_X + 10.0 + (BOOT_W / 2.0);
        HudDraw.drawBitmapCentered(dc, iconCX, contentY, bootIcon, BOOT_W, BOOT_H);

        var stepsText = "--";
        var info = ActivityMonitor.getInfo();
        if (info != null && info.steps != null) {
            stepsText = info.steps.toString();
        }

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(STEPS_BOX_X + STEPS_BOX_W - 8.0, contentY, Fonts.metricsFont(), stepsText,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawSolarBox(dc as Graphics.Dc, textColor as Number) as Void {
        var contentY = SOLAR_BOX_Y + (SOLAR_BOX_H * 0.66);
        var label = "--:--";
        var isRise = true;
        var evLabel = _cache.solarEventLabel;
        var evMoment = _cache.solarEventMoment;
        if (evLabel != null && evMoment != null) {
            isRise = evLabel.equals("RISE");
            var info2 = Gregorian.info(evMoment, Time.FORMAT_SHORT);
            label = Lang.format("$1$:$2$", [info2.hour.format("%02d"), info2.min.format("%02d")]);
        }

        // V5: client - "remove the word solar and instead use Sunrise or
        // Sunset depending on what the value is."
        var boxLabel = isRise ? "SUNRISE" : "SUNSET";
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(SOLAR_BOX_X + 8.0, SOLAR_BOX_Y + 2.0, Fonts.labelsFont(), boxLabel, Graphics.TEXT_JUSTIFY_LEFT);

        var solarIcon;
        if (_isSleeping) {
            solarIcon = isRise ? _iconSolarRiseAod : _iconSolarSetAod;
        } else {
            solarIcon = isRise ? _iconSolarRiseDay : _iconSolarSetDay;
        }

        // V5: client - icon/time were colliding. Actually scaled down this
        // time (drawBitmapScaledCentered, not drawBitmapCentered - the
        // first attempt only changed the centering-math constants, which
        // doesn't resize the bitmap itself, same class of bug hit with the
        // boot icon earlier), kept snug against the box's left edge to
        // free real horizontal gap before the value text's left edge -
        // verified against a forced worst-case "18:46" string above, not
        // just the common "--:--" placeholder.
        var iconCX = SOLAR_BOX_X + 6.0 + (SOLAR_DISPLAY_SIZE / 2.0);
        HudDraw.drawBitmapScaledCentered(dc, iconCX, contentY, solarIcon, SOLAR_W, SOLAR_H,
            SOLAR_DISPLAY_SIZE, SOLAR_DISPLAY_SIZE);

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(SOLAR_BOX_X + SOLAR_BOX_W - 8.0, contentY, Fonts.metricsFont(), label,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawDateBox(dc as Graphics.Dc, textColor as Number) as Void {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dayName = DAY_ABBREV[info.day_of_week];
        var ddMm = Properties.getValue("dateFormatDDMM") as Number;
        var dateNums = (ddMm == 1)
            ? Lang.format("$1$/$2$", [info.day.format("%02d"), info.month.format("%02d")])
            : Lang.format("$1$/$2$", [info.month.format("%02d"), info.day.format("%02d")]);

        var cx = DATE_BOX_X + (DATE_BOX_W / 2.0);
        var cy = DATE_BOX_Y + (DATE_BOX_H / 2.0);

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Fonts.dateFont(), dayName + " " + dateNums, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // V6 task 4: Timezone 2 (west-coast/Pacific by default), configurable
    // via the new `timezone2` list setting. There is no public Connect IQ
    // API for the watch's native "Time Zone 2" device setting (confirmed
    // against the local SDK docs - ClockTime.timeZoneOffset only exposes
    // the PRIMARY zone), so this is entirely our own setting + DST math -
    // see TzCalc.mc. Sits beside the primary date, split by a thin
    // vertical divider instead of a second box, per task 1.
    private function drawTz2Box(dc as Graphics.Dc, textColor as Number) as Void {
        var zoneId = Properties.getValue("timezone2") as Number?;
        if (zoneId == null) {
            zoneId = TzCalc.ZONE_PACIFIC;
        }

        var hourMinute = TzCalc.currentHourMinute(zoneId);
        var timeStr = Lang.format("$1$:$2$", [hourMinute[0].format("%02d"), hourMinute[1].format("%02d")]);
        var label = TzCalc.zoneLabel(zoneId);

        var cx = TZ2_BOX_X + (TZ2_BOX_W / 2.0);
        var cy = TZ2_BOX_Y + (TZ2_BOX_H / 2.0);

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Fonts.dateFont(), timeStr + " " + label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Weather gets its own dedicated box in V2 (superseding V1's combined
    // WX+BT/notification row). V3: the "WX" text label is removed (client
    // feedback, same pattern as the earlier PWR/HR label removals - the
    // icon becomes its own label) and the Bluetooth/bell icons that used to
    // flank this box moved up to flank the Battery/HR row instead (see
    // drawStatusFlanking(), now called from onUpdate() next to those boxes).
    // The horizontal room the label used to occupy is reclaimed by the
    // weather icon: its left inset shrank from 22px to 8px, shifting it left
    // into that freed space and opening up real breathing room between the
    // icon and the temperature text rather than leaving the space empty.
    private function drawWeatherBox(dc as Graphics.Dc, textColor as Number) as Void {
        var cy = WX_BOX_Y + (WX_BOX_H / 2.0);

        var fullBucket = HudDraw.mapConditionToBucket(_cache.weatherCondition);
        var icon;
        if (_isSleeping) {
            // Always-On simplifies to 2 states per the brief: clear/cloudy
            // collapse to the plain clear glyph, everything else collapses
            // to the plain overcast glyph.
            icon = (fullBucket == :clear || fullBucket == :cloudy) ? _iconWxClearAod : _iconWxOvercastAod;
        } else if (fullBucket == :clear) {
            icon = _iconWxClearDay;
        } else if (fullBucket == :cloudy) {
            icon = _iconWxCloudyDay;
        } else if (fullBucket == :rain) {
            icon = _iconWxRainDay;
        } else if (fullBucket == :snow) {
            icon = _iconWxSnowDay;
        } else if (fullBucket == :storm) {
            icon = _iconWxStormDay;
        } else {
            icon = _iconWxOvercastDay;
        }

        var statusIconSize = WX_BOX_H - 2.0;
        // V3: inset shrunk 22 -> 8 - reclaims the space the "WX" label used
        // to occupy, shifting the icon left instead of leaving that room
        // empty.
        var wxIconCX = WX_BOX_X + 8.0 + (statusIconSize / 2.0);
        HudDraw.drawBitmapScaledCentered(dc, wxIconCX, cy, icon, WX_W, WX_H, statusIconSize, statusIconSize);

        // Client polish pass: box grew 16->20px tall specifically to make
        // room for a bigger icon (statusIconSize above is WX_BOX_H-2, so
        // 14->18px automatically) and bigger temp text - now uses
        // FntMetrics (13px, the same size every other stat box's value
        // uses) instead of the old FntFooter (11px) fallback that only
        // existed because the box used to be too short for it.
        var tempText = formatTemperature(_cache.weatherTemperatureC);
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(WX_BOX_X + WX_BOX_W - 6.0, cy, Fonts.tempValueFont(), tempText,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // V3: Bluetooth connection glyph (+ live connected/disconnected dot) and
    // the notification bell (+ live unread-count badge, skipped when the
    // count is 0) moved here from flanking the Weather box - client: "It
    // should be to the left and right of the battery and heart where there
    // is that little cut out." Bluetooth sits in the gap between the left
    // bezel margin and the Battery box's left edge; the bell sits in the
    // mirrored gap on the right of the HR box.
    //
    // Vertical position is NOT the row's literal center (Y=50, halfway
    // between BATT_BOX_Y=28 and +44=72) - the safe bezel half-width at this
    // row is tighter near the top (e.g. ~84px chord half-width at Y=28) than
    // lower down (~122px at Y=72), the same corner-distance math used
    // throughout this file. Anchoring at BATT_BOX_Y + BATT_BOX_H*0.66
    // (Y=57.04, the same fraction the Steps/Solar content rows already use)
    // lands both icons' worst corner (top, facing the row's tight side) at
    // ~124.5px from the true (140,140)/r=140 center - a ~15.5px margin, well
    // past the >=6px convention - while the notification-count badge's
    // worst-case text ("9+" at ~12px wide) still keeps a ~6.7px margin at
    // its own worst corner. Both real screenshot-verified, not just
    // computed - see the sprint report.
    private function drawStatusFlanking(dc as Graphics.Dc, textColor as Number, panelColor as Number) as Void {
        var deviceSettings = System.getDeviceSettings();
        var phoneConnected = deviceSettings.phoneConnected;
        var notifCount = deviceSettings.notificationCount;

        var btIcon = _isSleeping ? _iconBluetoothAod : _iconBluetoothDay;
        var bellIcon = _isSleeping ? _iconBellAod : _iconBellDay;
        var iconSize = STATUS_ICON_SIZE;
        var cy = BATT_BOX_Y + (BATT_BOX_H * 0.66);

        var btCX = BATT_BOX_X - STATUS_ICON_GAP - (iconSize / 2.0);
        HudDraw.drawBitmapScaledCentered(dc, btCX, cy, btIcon, BT_W, BT_H, iconSize, iconSize);

        // Connection-status dot is live state, not decoration - shown in
        // both modes: text color when the phone link is up, dim panel
        // color when it's down.
        var dotColor = phoneConnected ? textColor : panelColor;
        dc.setColor(dotColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(btCX + (iconSize * 0.30), cy - (iconSize * 0.30), 2.0);

        var bellCX = HR_BOX_X + HR_BOX_W + STATUS_ICON_GAP + (iconSize / 2.0);
        HudDraw.drawBitmapScaledCentered(dc, bellCX, cy, bellIcon, BELL_W, BELL_H, iconSize, iconSize);

        if (notifCount > 0) {
            var countText = (notifCount > 9) ? "9+" : notifCount.toString();
            dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(bellCX + (iconSize / 2.0) + 3.0, cy, Fonts.labelsFont(), countText,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Small centered callsign banner with a short tactical flourish tick on
    // each side - kept in both modes (it's static chrome, same cost as the
    // panel borders, not a per-second animation).
    //
    // V6 task 5: "BRAVO-4" was hardcoded - now reads the `squad` string
    // property (default "BRAVO-4") so any soldier can rename it via the
    // Garmin Connect Mobile companion app, no recompile. Defensively
    // clamped to 8 chars and the flourish outer extent is capped against
    // FOOTER_MAX_HALF_W (this row sits right at the bottom pole, the
    // tightest bezel margin on the face - see the constant's own comment)
    // so a long user-supplied callsign can never push the flourish past
    // the bezel-safe edge.
    private function drawFooter(dc as Graphics.Dc, textColor as Number) as Void {
        var text = Properties.getValue("squad") as String?;
        if (text == null || text.length() == 0) {
            text = "BRAVO-4";
        }
        if (text.length() > 8) {
            text = text.substring(0, 8);
        }

        var font = Fonts.footerFont();
        var dims = dc.getTextDimensions(text, font);
        var cy = FOOTER_Y + (FOOTER_H / 2.0);

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(FOOTER_CX, cy, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var flourishInner = (dims[0] / 2.0) + 6.0;
        var flourishOuter = flourishInner + 10.0;
        if (flourishOuter > FOOTER_MAX_HALF_W) {
            flourishOuter = FOOTER_MAX_HALF_W;
        }
        dc.setPenWidth(1);
        if (flourishOuter > flourishInner) {
            dc.drawLine(FOOTER_CX - flourishOuter, cy, FOOTER_CX - flourishInner, cy);
            dc.drawLine(FOOTER_CX + flourishInner, cy, FOOTER_CX + flourishOuter, cy);
        }
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

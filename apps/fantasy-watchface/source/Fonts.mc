import Toybox.Graphics;
import Toybox.Lang;

// Same Graphics.getVectorFont()-with-fixed-fallback pattern apache-
// watchface's Fonts.mc uses (see that file's history for why: Connect IQ's
// <font> resource pipeline wants a pre-rendered AngelCode BMFont atlas, not
// a raw TTF, so a "custom" typeface always resolves to one of the device's
// built-in vector faces instead).
//
// Every role below gets TWO getters - a "stone" (normal) size and a "rune"
// (smaller) size - for the dual-layer "etched stone / glowing rune" text
// treatment (see ThemeText.mc). The rune size is always
// round(stoneSize * RUNE_RATIO), clamped to a 6px floor so it never
// vanishes into an unreadable sliver at this face's smaller font roles
// (labels/date/lore all sit near or below 8px stone already).
module Fonts {
    const FACE_NUMERIC = "sourceSansPro"; // clock/metric/value roles
    const FACE_STENCIL = "leagueGothic";  // label/date/header-ish roles

    // Settled on via a zoomed screenshot check of the clock (see
    // CLAUDE.md) - 0.90 nearly disappeared behind the stone glyph, 0.75
    // read as a blurry double-stroke rather than a distinct inner glow.
    // 0.82 reads as a clearly smaller, clearly brighter core without
    // muddying the outline.
    const RUNE_RATIO = 0.82;
    const RUNE_MIN_PX = 6;

    function runeSize(stoneSize as Number) as Number {
        var s = (stoneSize * RUNE_RATIO).toNumber();
        return (s < RUNE_MIN_PX) ? RUNE_MIN_PX : s;
    }

    var _timeStone as Graphics.FontType?;
    var _timeRune as Graphics.FontType?;
    var _secondsStone as Graphics.FontType?;
    var _secondsRune as Graphics.FontType?;
    var _dateStone as Graphics.FontType?;
    var _dateRune as Graphics.FontType?;
    var _metricsStone as Graphics.FontType?;
    var _metricsRune as Graphics.FontType?;
    var _batteryValueStone as Graphics.FontType?;
    var _batteryValueRune as Graphics.FontType?;
    var _tempValueStone as Graphics.FontType?;
    var _tempValueRune as Graphics.FontType?;
    var _footerStone as Graphics.FontType?;
    var _footerRune as Graphics.FontType?;
    var _labelsStone as Graphics.FontType?;
    var _labelsRune as Graphics.FontType?;
    var _loreStone as Graphics.FontType?;
    var _loreRune as Graphics.FontType?;

    const SIZE_TIME = 34;
    const SIZE_SECONDS = 18;
    const SIZE_DATE = 8;
    const SIZE_METRICS = 13;
    const SIZE_BATTERY_VALUE = 9;
    const SIZE_TEMP_VALUE = 10;
    const SIZE_FOOTER = 11;
    const SIZE_LABELS = 7;
    const SIZE_LORE = 7;

    function timeFont() as Graphics.FontType {
        if (_timeStone == null) {
            _timeStone = load(FACE_NUMERIC, SIZE_TIME, Graphics.FONT_NUMBER_MEDIUM);
        }
        return _timeStone as Graphics.FontType;
    }

    function timeFontRune() as Graphics.FontType {
        if (_timeRune == null) {
            _timeRune = load(FACE_NUMERIC, runeSize(SIZE_TIME), Graphics.FONT_NUMBER_MILD);
        }
        return _timeRune as Graphics.FontType;
    }

    function secondsFont() as Graphics.FontType {
        if (_secondsStone == null) {
            _secondsStone = load(FACE_NUMERIC, SIZE_SECONDS, Graphics.FONT_NUMBER_MILD);
        }
        return _secondsStone as Graphics.FontType;
    }

    function secondsFontRune() as Graphics.FontType {
        if (_secondsRune == null) {
            _secondsRune = load(FACE_NUMERIC, runeSize(SIZE_SECONDS), Graphics.FONT_XTINY);
        }
        return _secondsRune as Graphics.FontType;
    }

    // Shared by the primary Date box and the Timezone2 box, same as
    // apache-watchface.
    function dateFont() as Graphics.FontType {
        if (_dateStone == null) {
            _dateStone = load(FACE_STENCIL, SIZE_DATE, Graphics.FONT_XTINY);
        }
        return _dateStone as Graphics.FontType;
    }

    function dateFontRune() as Graphics.FontType {
        if (_dateRune == null) {
            _dateRune = load(FACE_STENCIL, runeSize(SIZE_DATE), Graphics.FONT_XTINY);
        }
        return _dateRune as Graphics.FontType;
    }

    // Shared by HR / Steps / Solar value text.
    function metricsFont() as Graphics.FontType {
        if (_metricsStone == null) {
            _metricsStone = load(FACE_NUMERIC, SIZE_METRICS, Graphics.FONT_SMALL);
        }
        return _metricsStone as Graphics.FontType;
    }

    function metricsFontRune() as Graphics.FontType {
        if (_metricsRune == null) {
            _metricsRune = load(FACE_NUMERIC, runeSize(SIZE_METRICS), Graphics.FONT_XTINY);
        }
        return _metricsRune as Graphics.FontType;
    }

    function batteryValueFont() as Graphics.FontType {
        if (_batteryValueStone == null) {
            _batteryValueStone = load(FACE_NUMERIC, SIZE_BATTERY_VALUE, Graphics.FONT_XTINY);
        }
        return _batteryValueStone as Graphics.FontType;
    }

    function batteryValueFontRune() as Graphics.FontType {
        if (_batteryValueRune == null) {
            _batteryValueRune = load(FACE_NUMERIC, runeSize(SIZE_BATTERY_VALUE), Graphics.FONT_XTINY);
        }
        return _batteryValueRune as Graphics.FontType;
    }

    function tempValueFont() as Graphics.FontType {
        if (_tempValueStone == null) {
            _tempValueStone = load(FACE_NUMERIC, SIZE_TEMP_VALUE, Graphics.FONT_XTINY);
        }
        return _tempValueStone as Graphics.FontType;
    }

    function tempValueFontRune() as Graphics.FontType {
        if (_tempValueRune == null) {
            _tempValueRune = load(FACE_NUMERIC, runeSize(SIZE_TEMP_VALUE), Graphics.FONT_XTINY);
        }
        return _tempValueRune as Graphics.FontType;
    }

    function footerFont() as Graphics.FontType {
        if (_footerStone == null) {
            _footerStone = load(FACE_NUMERIC, SIZE_FOOTER, Graphics.FONT_XTINY);
        }
        return _footerStone as Graphics.FontType;
    }

    function footerFontRune() as Graphics.FontType {
        if (_footerRune == null) {
            _footerRune = load(FACE_NUMERIC, runeSize(SIZE_FOOTER), Graphics.FONT_XTINY);
        }
        return _footerRune as Graphics.FontType;
    }

    // STP / SUNRISE / SUNSET small field labels.
    function labelsFont() as Graphics.FontType {
        if (_labelsStone == null) {
            _labelsStone = load(FACE_STENCIL, SIZE_LABELS, Graphics.FONT_XTINY);
        }
        return _labelsStone as Graphics.FontType;
    }

    function labelsFontRune() as Graphics.FontType {
        if (_labelsRune == null) {
            _labelsRune = load(FACE_STENCIL, runeSize(SIZE_LABELS), Graphics.FONT_XTINY);
        }
        return _labelsRune as Graphics.FontType;
    }

    // Lore-text paragraph field, under the clock.
    function loreFont() as Graphics.FontType {
        if (_loreStone == null) {
            _loreStone = load(FACE_NUMERIC, SIZE_LORE, Graphics.FONT_XTINY);
        }
        return _loreStone as Graphics.FontType;
    }

    function loreFontRune() as Graphics.FontType {
        if (_loreRune == null) {
            _loreRune = load(FACE_NUMERIC, runeSize(SIZE_LORE), Graphics.FONT_XTINY);
        }
        return _loreRune as Graphics.FontType;
    }

    function load(face as String, size as Number, fallback as Graphics.FontType) as Graphics.FontType {
        var f = null;
        try {
            f = Graphics.getVectorFont({ :face => face, :size => size });
        } catch (e) {
            f = null;
        }
        return (f != null) ? (f as Graphics.FontType) : fallback;
    }
}

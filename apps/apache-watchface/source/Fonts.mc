import Toybox.Graphics;
import Toybox.Lang;

// V2 spec asked for a custom "MFD-64" typeface family at 7 named sizes
// (FntTime 52, FntSeconds 34, FntDate 24, FntMetrics 20, FntHeader 18,
// FntFooter 16, FntLabels 10), substituting real Windows TTFs (Consolas
// Bold for numeric fields, Impact for header/date/label fields) since
// "MFD-64" doesn't exist.
//
// V2.1 client feedback (real screenshot): text was overlapping/unclear at
// those sizes - every named size below is scaled down ~1/3 (x0.67,
// rounded) from the original spec numbers above: FntTime 52->35,
// FntSeconds 34->23, FntDate 24->16, FntMetrics 20->13, FntHeader 18->12,
// FntFooter 16->11, FntLabels 10->7. Relative hierarchy between roles is
// preserved exactly (same ratios), only the absolute scale shrank.
//
// Real attempt made this session: copied consolab.ttf into
// resources/fonts/, declared it as a <font> resource, and ran it through
// the actual monkeyc compiler. Compile error:
//
//   Unable to process 'font' resources: "9B" is not a valid key/value pair.
//
// Root cause, confirmed against the SDK's own shipped docs
// (doc/docs/Core_Topics/Resources.html, "Fonts" section): the resource
// compiler's <font> element expects AngelCode BMFont TEXT-format output
// (a .fnt describing a pre-rasterized glyph atlas), not a raw TrueType
// outline file - it tried to parse the TTF's binary header as BMFont
// key/value text and choked on the first non-ASCII byte sequence.
// Separately, fontType's own schema (bin/resources.xsd) has no "size"
// attribute at all: a compiled font resource is a bitmap atlas baked at
// ONE fixed pixel size, not a scalable face, so getting 7 different sizes
// out of 2 physical files would require generating 7 separate BMFont
// atlases (a real bitmap-font-atlas generation pipeline), not a plain
// resource declaration - too much scope/risk to build blind in this pass.
//
// Fallback actually shipped: Graphics.getVectorFont(), a real, currently-
// supported on-device vector font engine (fenix7xpro is in VectorFont's
// supported-device list) that takes an arbitrary pixel :size - so all 7
// spec'd pixel sizes are honored exactly, just backed by one of the
// device's built-in vector typefaces (confirmed present on fenix7xpro via
// its compiler.json digitalFonts list: sourceSansPro, leagueGothic,
// notoSansCJKTC, qumpellkaNO12) instead of Consolas/Impact. "leagueGothic"
// (bold/condensed, technical-looking) substitutes for the Impact role;
// "sourceSansPro" substitutes for the Consolas/monospace role. Every call
// site null-checks the result and falls back one step further to a fixed
// Graphics.FONT_* enum constant, in case a face name isn't actually
// resolvable on a given device/firmware.
module Fonts {
    var _time as Graphics.FontType?;
    var _seconds as Graphics.FontType?;
    var _date as Graphics.FontType?;
    var _metrics as Graphics.FontType?;
    var _header as Graphics.FontType?;
    var _footer as Graphics.FontType?;
    var _labels as Graphics.FontType?;

    const FACE_NUMERIC = "sourceSansPro"; // Consolas-role substitute
    const FACE_STENCIL = "leagueGothic";  // Impact-role substitute

    function timeFont() as Graphics.FontType {
        if (_time == null) {
            _time = load(FACE_NUMERIC, 35, Graphics.FONT_NUMBER_MEDIUM);
        }
        return _time as Graphics.FontType;
    }

    function secondsFont() as Graphics.FontType {
        if (_seconds == null) {
            _seconds = load(FACE_NUMERIC, 23, Graphics.FONT_NUMBER_MILD);
        }
        return _seconds as Graphics.FontType;
    }

    function dateFont() as Graphics.FontType {
        if (_date == null) {
            _date = load(FACE_STENCIL, 16, Graphics.FONT_MEDIUM);
        }
        return _date as Graphics.FontType;
    }

    function metricsFont() as Graphics.FontType {
        if (_metrics == null) {
            _metrics = load(FACE_NUMERIC, 13, Graphics.FONT_SMALL);
        }
        return _metrics as Graphics.FontType;
    }

    function headerFont() as Graphics.FontType {
        if (_header == null) {
            _header = load(FACE_STENCIL, 12, Graphics.FONT_SMALL);
        }
        return _header as Graphics.FontType;
    }

    function footerFont() as Graphics.FontType {
        if (_footer == null) {
            _footer = load(FACE_NUMERIC, 11, Graphics.FONT_XTINY);
        }
        return _footer as Graphics.FontType;
    }

    function labelsFont() as Graphics.FontType {
        if (_labels == null) {
            _labels = load(FACE_STENCIL, 7, Graphics.FONT_XTINY);
        }
        return _labels as Graphics.FontType;
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

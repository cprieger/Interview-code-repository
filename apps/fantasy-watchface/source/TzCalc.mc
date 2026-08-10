import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

// V6: Time Zone 2 (west-coast/Pacific by default) support. Connect IQ has
// no public API to read the watch's native "Time Zone 2" device setting -
// confirmed against the local SDK docs, ClockTime.timeZoneOffset only
// exposes the PRIMARY zone already used by System.getClockTime(). So this
// is entirely a user-configurable setting (resources/settings/settings.xml
// `timezone2` list property, wired through ApacheWatchFaceView.drawTz2Box())
// plus our own manual DST math, not a read of any device/TZ-database API.
//
// IMPORTANT, discovered by actually running this in the simulator (not
// assumed from the docs): Gregorian.info(moment) ALWAYS converts through
// the DEVICE'S OWN configured local timezone when producing calendar
// fields, even for a Moment built from Gregorian.moment() with literal
// field values. A first implementation tried the "build a moment shifted
// by the target zone's offset, then read its fields back via
// Gregorian.info() as if they were the target zone's raw wall clock" trick
// - this is exactly how the rest of the app already reads its OWN local
// time (Gregorian.info(Time.now())), but for an ARBITRARY non-device zone
// it silently re-applies the device's own offset a second time on top of
// the manual shift. Caught in the simulator: with the host machine on
// CDT (UTC-5) and Pacific correctly at UTC-7 (DST active), the displayed
// TZ2 read ~5 hours short of the correct Pacific time - exactly the host's
// own CDT offset leaking back in. Confirmed by temporarily logging
// Gregorian.moment({:year=>2026,:month=>3,:day=>1,...}).value() (a clean
// UTC epoch for 2026-03-01 00:00:00, proving moment() DOES treat fields as
// literal UTC) against what Gregorian.info() on that same moment read back
// (Feb 28, one CDT-offset day earlier) - the read path, not the write
// path, is where the device timezone re-enters.
//
// Fix: do the epoch<->wall-clock math for both DST-boundary lookups and
// the live TZ2 readout with plain integer arithmetic on Moment.value()
// (raw UTC epoch seconds), never through Gregorian.info(), so nothing
// device-timezone-dependent can leak back in.
//
// DST rule (US): 2nd Sunday of March 2am STANDARD time (spring forward)
// through 1st Sunday of November 2am DAYLIGHT time (fall back). Hawaii and
// UTC never observe DST and skip this math entirely (always standard
// offset). Both transition instants use the offset that's actually live
// at that moment (_isDstActive passes stdOffsetSec for March, stdOffsetSec
// + 3600 for November) - not a "both computed the same way" shortcut, the
// two really do need different offsets to land on the correct UTC instant.
module TzCalc {
    const ZONE_PACIFIC = 0;
    const ZONE_MOUNTAIN = 1;
    const ZONE_CENTRAL = 2;
    const ZONE_EASTERN = 3;
    const ZONE_ALASKA = 4;
    const ZONE_HAWAII = 5;
    const ZONE_UTC = 6;

    const ZONE_LABELS as Array<String> = ["PT", "MT", "CT", "ET", "AKT", "HT", "UTC"];

    // Standard (non-DST) UTC offsets, in seconds. Index matches the
    // ZONE_* constants above and the `timezone2` settings.xml list values.
    const STD_OFFSETS_SEC as Array<Number> = [
        -8 * 3600, // Pacific
        -7 * 3600, // Mountain
        -6 * 3600, // Central
        -5 * 3600, // Eastern
        -9 * 3600, // Alaska
        -10 * 3600, // Hawaii - no DST
        0           // UTC - no DST
    ];

    const SECONDS_PER_DAY = 86400;

    function zoneLabel(zoneId as Number) as String {
        if (zoneId < 0 || zoneId >= ZONE_LABELS.size()) {
            return "??";
        }
        return ZONE_LABELS[zoneId];
    }

    // Live UTC-offset seconds for the given zone right now, honoring US
    // DST for the zones that observe it. Unknown/out-of-range zoneId
    // degrades to UTC (offset 0) rather than crashing - same null/garbage-
    // safe fallback convention every other sensor-derived field in this
    // app uses.
    function currentOffsetSeconds(zoneId as Number) as Number {
        if (zoneId < 0 || zoneId >= STD_OFFSETS_SEC.size()) {
            return 0;
        }
        var stdOffset = STD_OFFSETS_SEC[zoneId];
        if (zoneId == ZONE_HAWAII || zoneId == ZONE_UTC) {
            return stdOffset;
        }
        return _isDstActive(stdOffset) ? (stdOffset + 3600) : stdOffset;
    }

    // Current wall-clock [hour, minute] for the given zone, computed with
    // plain epoch-seconds arithmetic (see the class-level note on why this
    // deliberately does NOT go through Gregorian.info()).
    function currentHourMinute(zoneId as Number) as [Number, Number] {
        var offset = currentOffsetSeconds(zoneId);
        var totalSec = Time.now().value() + offset;
        var secOfDay = totalSec % SECONDS_PER_DAY;
        if (secOfDay < 0) {
            secOfDay += SECONDS_PER_DAY; // defensive; not expected for any real zone/epoch combo
        }
        var hour = secOfDay / 3600;
        var minute = (secOfDay % 3600) / 60;
        return [hour, minute];
    }

    function _isDstActive(stdOffsetSec as Number) as Boolean {
        var nowSec = Time.now().value();
        var year = _yearFromEpochSeconds(nowSec);

        var dstStartSec = _wallClockToUtcSeconds(year, 3, _nthSunday(year, 3, 2), 2, 0, 0, stdOffsetSec);
        var dstEndSec = _wallClockToUtcSeconds(year, 11, _nthSunday(year, 11, 1), 2, 0, 0, stdOffsetSec + 3600);

        return (nowSec >= dstStartSec) && (nowSec < dstEndSec);
    }

    // Calendar year for a raw UTC epoch-seconds value, via Gregorian.info()
    // - safe here (unlike the day-of-week case below) because a
    // device-local-timezone shift of at most ~14 hours can only ever push
    // the read-back date across a year boundary during the last/first day
    // of December/January, and even then this is only used to pick which
    // year's DST transition dates to compute, not a value displayed to
    // the user - a one-day error here can only matter in the literal
    // closing hours of Dec 31, an acceptable edge case for a secondary
    // display field.
    function _yearFromEpochSeconds(epochSec as Number) as Number {
        return Gregorian.info(new Time.Moment(epochSec), Time.FORMAT_SHORT).year;
    }

    // Day-of-month of the Nth Sunday in the given year/month (n=1 -> first
    // Sunday, n=2 -> second Sunday, etc). Deliberately does NOT use
    // Gregorian.info().day_of_week (see the class-level note - it reads
    // back through the device's own local timezone, which shifted a
    // literal UTC midnight moment onto the wrong calendar day in testing).
    // Instead computes day-of-week directly from days-since-epoch:
    // 1970-01-01 (epoch) was a Thursday, so
    // (daysSinceEpoch + 4) % 7 gives 0=Sunday..6=Saturday for any date,
    // independent of the device's configured timezone.
    function _nthSunday(year as Number, month as Number, n as Number) as Number {
        var firstOfMonth = Gregorian.moment({:year => year, :month => month, :day => 1, :hour => 0, :minute => 0, :second => 0});
        var daysSinceEpoch = firstOfMonth.value() / SECONDS_PER_DAY;
        var dow0 = (daysSinceEpoch + 4) % 7; // 0=Sunday..6=Saturday
        var daysToFirstSunday = (dow0 == 0) ? 0 : (7 - dow0);
        var firstSunday = 1 + daysToFirstSunday;
        return firstSunday + ((n - 1) * 7);
    }

    // Converts a local wall-clock date/time (given the offset that's live
    // AT that moment) into true UTC epoch seconds: local = UTC + offset,
    // so UTC = local - offset. Gregorian.moment() builds a moment's raw
    // epoch VALUE from the supplied fields as if they were literal UTC
    // fields (confirmed in testing - unlike Gregorian.info(), the write
    // path does NOT apply the device's local timezone), so subtracting the
    // offset converts that literal-fields moment into the real UTC instant
    // the wall-clock reading corresponds to.
    function _wallClockToUtcSeconds(year as Number, month as Number, day as Number,
                                             hour as Number, minute as Number, second as Number,
                                             offsetSec as Number) as Number {
        var literalMoment = Gregorian.moment({:year => year, :month => month, :day => day,
            :hour => hour, :minute => minute, :second => second});
        return literalMoment.value() - offsetSec;
    }
}

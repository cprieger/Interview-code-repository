import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Position;
import Toybox.Weather;
import Toybox.Activity;
import Toybox.ActivityMonitor;

// Holds sensor/weather/solar readings plus the refresh throttling described
// in the design brief:
//   - weather refresh: every 15 min awake, every 30-60 min (45 min) asleep
//   - heart rate refresh: every 5s awake, every 60s asleep
//   - solar (sunrise/sunset) event: computed once per calendar day
// Battery % and step count are cheap local stat reads (no I/O), so those are
// re-read on every draw rather than cached/throttled.
//
// Ported unchanged from apps/apache-watchface (V6) - sensor/refresh logic is
// device/theme-agnostic, no reason to fork it.
class DataCache {
    private const AWAKE_WEATHER_INTERVAL_SEC = 15 * 60;
    private const SLEEP_WEATHER_INTERVAL_SEC = 45 * 60;
    private const AWAKE_HR_INTERVAL_SEC = 5;
    private const SLEEP_HR_INTERVAL_SEC = 60;

    var weatherTemperatureC as Numeric?;
    var weatherCondition as Number?;
    private var _lastWeatherFetch as Number = 0;

    var heartRate as Number?;
    private var _lastHeartRateFetch as Number = 0;

    var solarEventLabel as String?; // "RISE" or "SET"
    var solarEventMoment as Time.Moment?;
    private var _solarCachedYmd as Number = -1;

    function initialize() {
    }

    function refresh(isSleeping as Boolean) as Void {
        var nowSec = Time.now().value();

        var weatherInterval = isSleeping ? SLEEP_WEATHER_INTERVAL_SEC : AWAKE_WEATHER_INTERVAL_SEC;
        if (nowSec - _lastWeatherFetch >= weatherInterval) {
            _refreshWeather();
            _lastWeatherFetch = nowSec;
        }

        var hrInterval = isSleeping ? SLEEP_HR_INTERVAL_SEC : AWAKE_HR_INTERVAL_SEC;
        if (nowSec - _lastHeartRateFetch >= hrInterval) {
            _refreshHeartRate();
            _lastHeartRateFetch = nowSec;
        }

        var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var ymd = (today.year * 10000) + (today.month * 100) + today.day;
        if (ymd != _solarCachedYmd) {
            _refreshSolarEvent();
            _solarCachedYmd = ymd;
        }
    }

    private function _refreshWeather() as Void {
        var conditions = Weather.getCurrentConditions();
        if (conditions != null) {
            weatherTemperatureC = conditions.temperature;
            weatherCondition = conditions.condition;
        }
    }

    private function _refreshHeartRate() as Void {
        var info = Activity.getActivityInfo();
        if (info != null && info.currentHeartRate != null) {
            heartRate = info.currentHeartRate;
        }
    }

    private function _refreshSolarEvent() as Void {
        var posInfo = Position.getInfo();
        var location = (posInfo != null) ? posInfo.position : null;
        if (location == null) {
            solarEventLabel = null;
            solarEventMoment = null;
            return;
        }

        var now = Time.now();
        var sunrise = Weather.getSunrise(location, now);
        var sunset = Weather.getSunset(location, now);

        if (sunrise != null && sunrise.value() > now.value()) {
            solarEventLabel = "RISE";
            solarEventMoment = sunrise;
        } else if (sunset != null && sunset.value() > now.value()) {
            solarEventLabel = "SET";
            solarEventMoment = sunset;
        } else {
            // Both today's events have passed - show tomorrow's sunrise.
            var tomorrow = now.add(new Time.Duration(24 * 60 * 60));
            var nextSunrise = Weather.getSunrise(location, tomorrow);
            solarEventLabel = "RISE";
            solarEventMoment = nextSunrise;
        }
    }
}

import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class FantasyWatchFaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    // Fires when a setting is changed from the Garmin Connect app.
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new FantasyWatchFaceView()] as [Views];
    }
}

function getApp() as FantasyWatchFaceApp {
    return Application.getApp() as FantasyWatchFaceApp;
}

import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class ApacheWatchFaceApp extends Application.AppBase {

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
        return [new ApacheWatchFaceView()] as [Views];
    }
}

function getApp() as ApacheWatchFaceApp {
    return Application.getApp() as ApacheWatchFaceApp;
}

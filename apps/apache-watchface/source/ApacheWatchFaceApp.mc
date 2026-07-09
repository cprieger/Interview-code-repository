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

    function getInitialView() as Array<Views or InputDelegates>? {
        return [new ApacheWatchFaceView()] as Array<Views or InputDelegates>;
    }
}

function getApp() as ApacheWatchFaceApp {
    return Application.getApp() as ApacheWatchFaceApp;
}

import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

(:background :glance)
class IntervalsApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getServiceDelegate() {
        return [new IntervalsServiceDelegate()];
    }

    function getGlanceView() {
        scheduleBackground();
        return [new IntervalsGlanceView()];
    }

    function getInitialView() {
        scheduleBackground();
        return [new IntervalsWidgetView(0), new IntervalsPageDelegate(0)];
    }

    // Repaint when settings arrive from the phone, so glance mode and page
    // toggles apply without relaunching.
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }

    // Data handed back by the background service via Background.exit().
    function onBackgroundData(data) {
        if (data instanceof Lang.Dictionary) {
            if (data["w"] != null) {
                Storage.setValue("data", data);
                Storage.deleteValue("err");
            } else if (data["err"] != null) {
                Storage.setValue("err", data["err"]);
            }
        }
        WatchUi.requestUpdate();
    }

    hidden function scheduleBackground() as Void {
        // Hourly temporal event; the system enforces a 5 minute floor.
        Background.registerForTemporalEvent(new Time.Duration(3600));
    }
}

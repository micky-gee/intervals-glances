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
        // Registering here also delivers any OAuth result Garmin cached while
        // the widget was closed during phone-side login.
        IntervalsAuth.init();
        return [new IntervalsWidgetView(0), new IntervalsPageDelegate(0)];
    }

    // Repaint when settings arrive from the phone, so glance mode and page
    // toggles apply without relaunching.
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }

    // The background service persists its own results (IntervalsSyncJob), so
    // this only needs to surface errors and repaint.
    function onBackgroundData(data) {
        if (data instanceof Lang.Dictionary && data["err"] != null) {
            Storage.setValue("err", data["err"]);
        }
        WatchUi.requestUpdate();
    }

    hidden function scheduleBackground() as Void {
        // Sync when the data actually changes rather than on a fixed clock:
        // at wake (overnight wellness) and after activities (load), each of
        // which schedules a delayed sync. The temporal event is the scheduler
        // itself, re-armed after every fire.
        if (Background has :registerForWakeEvent) {
            Background.registerForWakeEvent();
        }
        if (Background has :registerForActivityCompletedEvent) {
            Background.registerForActivityCompletedEvent();
        }
        IntervalsSchedule.ensureArmed();
    }
}

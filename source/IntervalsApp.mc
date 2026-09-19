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
        IntervalsComplications.publish();
        return [new IntervalsWidgetView(0), new IntervalsPageDelegate(0)];
    }

    // Repaint when settings arrive from the phone, so glance mode and page
    // toggles apply without relaunching.
    function onSettingsChanged() as Void {
        // The form scale setting changes what we publish, not just what we draw.
        IntervalsComplications.publish();
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

    // Wake and activity registrations persist on the device until they are
    // unregistered, so re-registering them is only worth doing occasionally.
    // This runs on the glance path, which the system enters every time the
    // glance takes focus, and re-registering there made taking focus wait on
    // two system calls that had nothing left to do.
    const EVENT_REREG = 7 * 24 * 3600;

    hidden function scheduleBackground() as Void {
        // Sync when the data actually changes rather than on a fixed clock:
        // at wake (overnight wellness) and after activities (load), each of
        // which schedules a delayed sync. The temporal event is the scheduler
        // itself, re-armed after every fire.
        var now = Time.now().value();
        var last = Storage.getValue("bgReg");
        // The clock going backwards would otherwise defer this indefinitely.
        if (!(last instanceof Lang.Number) || now - last > EVENT_REREG || now < last) {
            if (Background has :registerForWakeEvent) {
                Background.registerForWakeEvent();
            }
            if (Background has :registerForActivityCompletedEvent) {
                Background.registerForActivityCompletedEvent();
            }
            // ensureArmed() queries the system for the current registration,
            // which is another call the glance path should not make on every
            // focus. The background service re-arms itself after each fire, so
            // this only has to be a safety net.
            IntervalsSchedule.ensureArmed();
            Storage.setValue("bgReg", now);
        }
    }
}

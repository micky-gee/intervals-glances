import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

// Background service. Events never fetch immediately: data has to travel
// watch -> Garmin Connect -> intervals.icu before the API reflects it, so
// waking or finishing an activity just schedules the sync a little later.
// Only one temporal event may exist at a time, so it doubles as the scheduler.
(:background)
class IntervalsServiceDelegate extends System.ServiceDelegate {

    hidden var _job as IntervalsSyncJob?;

    function initialize() {
        ServiceDelegate.initialize();
    }

    // The scheduled sync fired.
    function onTemporalEvent() as Void {
        if (IntervalsApi.options() == null) {
            IntervalsSchedule.arm(IntervalsSchedule.IDLE);
            Background.exit({ "err" => "Not connected" });
            return;
        }
        if (IntervalsCache.authBlocked()) {
            // Revoked credentials: stop spending requests on 401s.
            IntervalsSchedule.arm(IntervalsSchedule.IDLE);
            Background.exit(null);
            return;
        }
        var cache = IntervalsCache.load();
        if (cache == null || !(cache["hist"] instanceof Lang.Number)) {
            // Nothing cached yet; the first (wide) fetch belongs to the
            // foreground, where there is memory for it.
            IntervalsSchedule.arm(IntervalsSchedule.IDLE);
            Background.exit(null);
            return;
        }
        var hist = cache["hist"] as Number;
        var gap = 0;
        if (cache["dn"] instanceof Lang.Number) {
            gap = IntervalsApi.todayIdx() - (cache["dn"] as Number);
            if (gap < 0) { gap = 0; }
        }
        var from = gap + IntervalsApi.DELTA_DAYS;
        if (from > hist - 1) { from = hist - 1; }

        _job = new IntervalsSyncJob(from, 0, hist, method(:onDone));
        _job.start();
    }

    function onDone(ok as Boolean) as Void {
        IntervalsSchedule.arm(IntervalsSchedule.IDLE);
        // The job already persisted everything; this just wakes the UI.
        Background.exit({ "synced" => ok });
    }

    // Overnight sleep, HRV and resting HR are recorded at wake, but only
    // reach intervals.icu once the watch has synced through Garmin Connect.
    function onWakeTime() as Void {
        IntervalsSchedule.arm(IntervalsSchedule.AFTER_WAKE);
        Background.exit(null);
    }

    // Load (CTL/ATL) moves when an activity lands upstream, which likewise
    // takes a few minutes after the activity ends.
    function onActivityCompleted(activity as Dictionary) as Void {
        IntervalsSchedule.arm(IntervalsSchedule.AFTER_ACTIVITY);
        Background.exit(null);
    }
}

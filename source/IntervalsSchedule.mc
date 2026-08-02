import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;

// The single temporal event doubles as the app's scheduler: every trigger
// (wake, activity, app start, a completed sync) re-arms it for the next
// sensible moment rather than polling on a fixed clock.
//
// Delays exist because the API lags the watch: sleep/HRV and activities only
// reach intervals.icu after the watch syncs through Garmin Connect. Each delay
// carries jitter so that thousands of watches waking at 06:00 don't all call
// the API in the same 15-minute rate-limit bucket.
(:background)
module IntervalsSchedule {

    // [base seconds, jitter span] per reason.
    const AFTER_WAKE = 0;
    const AFTER_ACTIVITY = 1;
    const IDLE = 2;

    const BASE = [45 * 60, 20 * 60, 6 * 3600] as Array<Number>;
    const SPREAD = [30 * 60, 10 * 60, 45 * 60] as Array<Number>;

    // Never schedule closer than the system's own floor for temporal events.
    const MIN_DELAY = 6 * 60;

    function arm(reason as Number) as Void {
        var delay = BASE[reason] + jitter(SPREAD[reason]);
        if (delay < MIN_DELAY) {
            delay = MIN_DELAY;
        }
        var at = Time.now().add(new Time.Duration(delay));
        try {
            Background.registerForTemporalEvent(at);
            Storage.setValue("nextSync", at.value());
            System.println("sched: reason " + reason + " in " + (delay / 60) + " min");
        } catch (e) {
            // Too soon after the previous event: fall back to the idle gap so
            // the app never ends up with nothing scheduled.
            try {
                Background.registerForTemporalEvent(
                    Time.now().add(new Time.Duration(BASE[IDLE])));
            } catch (e2) {
            }
        }
    }

    // Re-arm at app start if nothing is pending (first run, or the schedule
    // was lost). Cheap enough to check on every launch.
    function ensureArmed() as Void {
        if (Background.getTemporalEventRegisteredTime() == null) {
            arm(IDLE);
        }
    }

    // Deterministic per-install spread: seeded once, so a given watch keeps
    // its offset instead of re-randomising into a busy bucket every time.
    function jitter(span as Number) as Number {
        if (span <= 0) {
            return 0;
        }
        var seed = Storage.getValue("jseed");
        if (!(seed instanceof Lang.Number)) {
            seed = (Time.now().value() * 2654435761L).toNumber().abs();
            Storage.setValue("jseed", seed);
        }
        return seed % span;
    }
}

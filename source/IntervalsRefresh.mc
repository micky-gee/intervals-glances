import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// Foreground sync policy: decides *whether* and *how wide* to sync, then runs
// an IntervalsSyncJob. The fetching and merging live in the job so the
// background service shares exactly the same path.
module IntervalsRefresh {

    // Manual START: brief guard against double presses only.
    const MANUAL_BACKOFF = 60;
    // Opening the widget: wellness data changes daily, so there is nothing to
    // gain from a tighter cadence than this.
    const OPEN_STALE = 2 * 3600;

    // Transient: whether the START-triggered zoom overlay is showing. Lives
    // here (a foreground-only module) so the view and delegate share it
    // without pulling anything into glance scope.
    var zoomActive as Boolean = false;

    var _driver as Driver? = null;

    function driver() as Driver {
        if (_driver == null) {
            _driver = new Driver();
        }
        return _driver;
    }

    function isBusy() as Boolean {
        return driver().busy;
    }

    // START button: the user explicitly asked, so only the double-press guard
    // and the auth backoff apply.
    function start() as Void {
        driver().start(false);
    }

    // Straight after linking an account: skip the double-press guard.
    function startNow() as Void {
        driver().start(true);
    }

    // Widget opened: sync only if the cache is cold, incomplete, or stale.
    function startIfStale() as Void {
        driver().startIfStale();
    }

    // The user zoomed past the history we hold: fetch just the missing older
    // days once.
    function backfillHistory() as Void {
        driver().backfill();
    }

    class Driver {
        var busy as Boolean = false;
        hidden var _job as IntervalsSyncJob? = null;
        hidden var _lastAttempt as Number = 0;

        function initialize() {
        }

        function start(force as Boolean) as Void {
            var now = Time.now().value();
            if (busy || (!force && now - _lastAttempt < MANUAL_BACKOFF)) {
                return;
            }
            run(plannedFrom(), 0, plannedHist());
        }

        function startIfStale() as Void {
            if (busy) {
                return;
            }
            var cold = IntervalsData.histDays() == 0 || missingDepth() > 0;
            var age = IntervalsData.ageSecs();
            if (!cold && age != null && age < OPEN_STALE) {
                return;
            }
            run(plannedFrom(), 0, plannedHist());
        }

        function backfill() as Void {
            var have = IntervalsData.histDays();
            if (busy || have <= 0 || have >= IntervalsApi.MAX_HIST) {
                return;
            }
            run(IntervalsApi.MAX_HIST - 1, have, IntervalsApi.MAX_HIST);
        }

        // Days back a sync must reach to fill series the cache lacks (0 when
        // none): the whole cached span for a graph metric, but only the
        // sparkline window for a data-page metric. Either happens when the
        // user changes a page since the last sync.
        hidden function missingDepth() as Number {
            var have = IntervalsData.histDays();
            var d = IntervalsData.data();
            if (d == null || !(d["s"] instanceof Lang.Dictionary)) {
                return have;
            }
            var s = d["s"] as Dictionary;
            var keys = IntervalsApi.selectedChartKeys();
            for (var i = 0; i < keys.size(); i++) {
                if (!s.hasKey(keys[i])) {
                    return have;
                }
            }
            var p = IntervalsCache.loadSpark();
            keys = IntervalsApi.selectedSparkKeys();
            for (var i = 0; i < keys.size(); i++) {
                if (!p.hasKey(keys[i])) {
                    return have < IntervalsApi.SPARK_DAYS ? have : IntervalsApi.SPARK_DAYS;
                }
            }
            return 0;
        }

        // How far back this sync must reach: just the mutable tail normally,
        // further when a series is missing from the cache.
        hidden function plannedFrom() as Number {
            var have = IntervalsData.histDays();
            if (have <= 0) {
                return IntervalsApi.INITIAL_HIST - 1;
            }
            var from = IntervalsData.daysSinceNewest() + IntervalsApi.DELTA_DAYS;
            var missing = missingDepth() - 1;
            if (missing > from) {
                from = missing;
            }
            return from > have - 1 ? have - 1 : from;
        }

        hidden function plannedHist() as Number {
            var have = IntervalsData.histDays();
            return have > 0 ? have : IntervalsApi.INITIAL_HIST;
        }

        hidden function run(fromDaysBack as Number, toDaysBack as Number,
                hist as Number) as Void {
            if (IntervalsApi.options() == null || IntervalsCache.authBlocked()) {
                return;
            }
            _lastAttempt = Time.now().value();
            busy = true;
            _job = new IntervalsSyncJob(fromDaysBack, toDaysBack, hist,
                method(:onDone));
            _job.start();
            WatchUi.requestUpdate();
        }

        function onDone(ok as Boolean) as Void {
            busy = false;
            _job = null;
            WatchUi.requestUpdate();
        }
    }
}

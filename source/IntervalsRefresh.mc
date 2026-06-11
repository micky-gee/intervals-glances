import Toybox.Application.Storage;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// Foreground refresh, used when the widget is opened with stale data or the
// user presses START. Same requests as the background service.
module IntervalsRefresh {

    var _fetcher as Fetcher? = null;
    var _lastAttempt as Number = 0;

    function isBusy() as Boolean {
        return _fetcher != null && _fetcher.busy;
    }

    function start() as Void {
        if (isBusy() || IntervalsSettings.apiKey() == null) {
            return;
        }
        // Don't hammer the API when something keeps failing.
        var now = Time.now().value();
        if (now - _lastAttempt < 60) {
            return;
        }
        _lastAttempt = now;
        _fetcher = new Fetcher();
        _fetcher.start();
    }

    // Refresh if never synced, data is older than 15 minutes, or the chart
    // configuration changed since the cached series were fetched.
    function startIfStale() as Void {
        var age = IntervalsData.ageSecs();
        if (age == null || age > 900 || missingSeries()) {
            start();
        }
    }

    function missingSeries() as Boolean {
        var d = IntervalsData.data();
        if (d == null) {
            return true;
        }
        if (d["wd"] != IntervalsSettings.windowDays()) {
            return true;
        }
        var s = d["s"];
        if (!(s instanceof Lang.Dictionary)) {
            return true;
        }
        var keys = IntervalsApi.selectedChartKeys();
        for (var i = 0; i < keys.size(); i++) {
            if (!s.hasKey(keys[i])) {
                return true;
            }
        }
        return false;
    }

    class Fetcher {
        var busy as Boolean = false;
        hidden var _summary as Dictionary?;
        hidden var _trend as IntervalsTrendFetcher?;

        function initialize() {
        }

        function start() as Void {
            var key = IntervalsSettings.apiKey();
            if (key == null) {
                return;
            }
            busy = true;
            Communications.makeWebRequest(
                IntervalsApi.wellnessUrl(IntervalsSettings.athleteId()),
                IntervalsApi.recentParams(),
                IntervalsApi.options(key),
                method(:onRecent));
        }

        function onRecent(code as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
            var resp = data as Lang.Object?;
            if (code == 200 && resp instanceof Lang.Array) {
                _summary = IntervalsApi.summarize(resp);
                _trend = new IntervalsTrendFetcher(method(:onTrendDone));
                _trend.start();
            } else {
                busy = false;
                System.println("sync failed: " + code);
                Storage.setValue("err", IntervalsApi.errorText(code));
                WatchUi.requestUpdate();
            }
        }

        function onTrendDone(series as Dictionary?) as Void {
            var out = {
                "ts" => Time.now().value(),
                "w" => _summary,
                "wd" => IntervalsSettings.windowDays()
            };
            if (series != null) {
                out["s"] = series;
            }
            Storage.setValue("data", out);
            Storage.deleteValue("err");
            busy = false;
            var w = _summary;
            System.println("sync ok: ctl=" + (w != null ? w["ctl"] : null)
                + " atl=" + (w != null ? w["atl"] : null)
                + " series=" + (series != null));
            WatchUi.requestUpdate();
        }
    }
}

import Toybox.Application.Storage;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.Time;

// One sync: fetch a day window (chunked only when it is long), merge the
// records into the cache, persist. Both the foreground refresher and the
// background service drive this, so it must not touch WatchUi.
//
// A normal sync asks for DELTA_DAYS+1 days and issues a single request; the
// wide fetches only happen on a cold cache or a history backfill.
(:background)
class IntervalsSyncJob {

    hidden var _done as Method(ok as Boolean) as Void;
    hidden var _hist as Number;
    hidden var _chunks as Array;
    hidden var _idx as Number = 0;
    hidden var _recs as Array = [];

    // from/to are days before today, inclusive: (1, 0) is yesterday+today.
    function initialize(fromDaysBack as Number, toDaysBack as Number,
            hist as Number, done as Method(ok as Boolean) as Void) {
        _done = done;
        _hist = hist;
        _chunks = IntervalsApi.windowChunks(fromDaysBack, toDaysBack);
    }

    function requestCount() as Number {
        return _chunks.size();
    }

    function start() as Void {
        request();
    }

    hidden function request() as Void {
        if (_idx >= _chunks.size()) {
            commit();
            return;
        }
        var opts = IntervalsApi.options();
        if (opts == null) {
            finish(false, "Not connected");
            return;
        }
        var ch = _chunks[_idx] as Array;
        System.println("sync: request " + (_idx + 1) + "/" + _chunks.size()
            + " " + ch[0] + ".." + ch[1]);
        Communications.makeWebRequest(
            IntervalsApi.wellnessUrl(IntervalsSettings.athleteId()),
            {
                "oldest" => ch[0],
                "newest" => ch[1],
                "fields" => IntervalsApi.unionFields()
            },
            opts,
            method(:onChunk));
    }

    function onChunk(code as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        // JSON arrays arrive as Lang.Array at runtime even though the
        // documented callback type omits it.
        var resp = data as Lang.Object?;
        if (code == 200 && resp instanceof Lang.Array) {
            for (var i = 0; i < resp.size(); i++) {
                _recs.add(resp[i]);
            }
            _idx++;
            request();
            return;
        }
        if (code == 401 || code == 403) {
            IntervalsCache.noteAuthFailure();
        }
        finish(false, IntervalsApi.errorText(code));
    }

    hidden function commit() as Void {
        if (_recs.size() == 0) {
            finish(false, "No data");
            return;
        }
        try {
            var merged = IntervalsCache.merge(IntervalsCache.load(), _recs, _hist);
            IntervalsCache.save(merged);
            IntervalsCache.clearAuthFailure();
            System.println("sync: ok, " + _recs.size() + " records, hist " + _hist);
            finish(true, null);
        } catch (e) {
            System.println("sync: merge failed");
            finish(false, "Sync failed");
        }
    }

    hidden function finish(ok as Boolean, err as String?) as Void {
        if (!ok && err != null) {
            Storage.setValue("err", err);
        } else if (ok) {
            Storage.deleteValue("err");
        }
        _done.invoke(ok);
    }
}

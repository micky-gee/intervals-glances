import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;

// Fetches the trend window in <=30 day chunks (oldest first), merging the
// results into one series dictionary. Used by both the background service
// and the foreground refresher; calls done(series or null) when finished.
(:background)
class IntervalsTrendFetcher {

    hidden var _done as Method(series as Dictionary?) as Void;
    hidden var _acc as Dictionary?;
    hidden var _chunks as Array = [];
    hidden var _idx as Number = 0;

    function initialize(done as Method(series as Dictionary?) as Void) {
        _done = done;
    }

    function start() as Void {
        var key = IntervalsSettings.apiKey();
        if (key == null) {
            _done.invoke(null);
            return;
        }
        _acc = IntervalsApi.initSeriesAcc();
        _chunks = IntervalsApi.trendChunks();
        _idx = 0;
        request();
    }

    hidden function request() as Void {
        if (_idx >= _chunks.size()) {
            _done.invoke(IntervalsApi.finishSeries(_acc));
            return;
        }
        var key = IntervalsSettings.apiKey();
        if (key == null) {
            _done.invoke(null);
            return;
        }
        var ch = _chunks[_idx] as Array;
        Communications.makeWebRequest(
            IntervalsApi.wellnessUrl(IntervalsSettings.athleteId()),
            {
                "oldest" => ch[0],
                "newest" => ch[1],
                "fields" => IntervalsApi.trendFields()
            },
            IntervalsApi.options(key),
            method(:onChunk));
    }

    function onChunk(code as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        var resp = data as Lang.Object?;
        if (code == 200 && resp instanceof Lang.Array) {
            IntervalsApi.appendSeries(_acc, resp);
            _idx++;
            request();
        } else {
            System.println("trend chunk failed: code=" + code);
            _done.invoke(null);
        }
    }
}

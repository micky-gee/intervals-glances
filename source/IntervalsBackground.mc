import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.Time;

// Periodic background fetch: recent wellness summary, then the 42 day
// ctl/atl trend, then exit with a compact dictionary for the foreground.
(:background)
class IntervalsServiceDelegate extends System.ServiceDelegate {

    hidden var _summary as Dictionary?;
    hidden var _trend as IntervalsTrendFetcher?;

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var key = IntervalsSettings.apiKey();
        if (key == null) {
            Background.exit({ "err" => "Set API key" });
            return;
        }
        Communications.makeWebRequest(
            IntervalsApi.wellnessUrl(IntervalsSettings.athleteId()),
            IntervalsApi.recentParams(),
            IntervalsApi.options(key),
            method(:onRecent));
    }

    function onRecent(code as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        // JSON array bodies actually arrive as Lang.Array at runtime even
        // though the documented callback type omits it; erase the static
        // type so the instanceof branch is not flagged unreachable.
        var resp = data as Lang.Object?;
        if (code == 200 && resp instanceof Lang.Array) {
            _summary = IntervalsApi.summarize(resp);
            _trend = new IntervalsTrendFetcher(method(:onTrendDone));
            _trend.start();
            return;
        }
        Background.exit({ "err" => IntervalsApi.errorText(code) });
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
        try {
            Background.exit(out);
        } catch (e) {
            // Series too large for the background exit payload; at least
            // deliver the summary.
            out.remove("s");
            Background.exit(out);
        }
    }
}

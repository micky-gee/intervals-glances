import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Communications;
import Toybox.StringUtil;

// Request building for the intervals.icu API. One shape of request serves
// everything: a date window with a field filter. Syncs normally ask for the
// last day or two and merge the result into the cache (IntervalsCache), since
// past wellness days are immutable.
(:background)
module IntervalsApi {

    // Days of history a fresh cache loads. The rest is fetched only if the
    // user zooms past it (IntervalsData.MAX_ZOOM).
    const INITIAL_HIST = 30;
    const MAX_HIST = 90;

    // Days re-fetched on every sync: today always changes, and yesterday can
    // still be edited or arrive late.
    const DELTA_DAYS = 1;

    // A single response must stay inside the watch's HTTP buffer (error -402
    // beyond roughly a month of wide records).
    const CHUNK_DAYS = 30;

    // Wellness fields shown on the tile pages.
    const FIELDS_RECENT =
        "id,ctl,atl,rampRate," +
        "restingHR,hrv,hrvSDNN,avgSleepingHR,readiness,baevskySI," +
        "sleepSecs,sleepScore,sleepQuality,respiration,spO2," +
        "weight,bodyFat,vo2max,systolic,diastolic,bloodGlucose," +
        "steps,kcalConsumed,carbohydrates,protein,fatTotal,hydrationVolume," +
        "soreness,fatigue,stress,mood,motivation,injury";

    function wellnessUrl(athleteId as String) as String {
        return "https://intervals.icu/api/v1/athlete/" + athleteId + "/wellness";
    }

    // Request options for the active auth method: Bearer when an OAuth
    // token is linked, else Basic with the (legacy) API key. Null when
    // neither is configured.
    function options() as Dictionary? {
        var auth;
        var token = IntervalsSettings.oauthToken();
        if (token != null) {
            auth = "Bearer " + token;
        } else {
            var apiKey = IntervalsSettings.apiKey();
            if (apiKey == null) {
                return null;
            }
            var b64 = StringUtil.convertEncodedString("API_KEY:" + apiKey, {
                :fromRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
                :toRepresentation => StringUtil.REPRESENTATION_STRING_BASE64
            });
            auth = "Basic " + b64;
        }
        return {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => { "Authorization" => auth },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
    }

    function dateStr(moment as Time.Moment) as String {
        var g = Gregorian.info(moment, Time.FORMAT_SHORT);
        return g.year.format("%04d") + "-" + g.month.format("%02d") + "-" + g.day.format("%02d");
    }




    function momentDaysBack(days as Number) as Time.Moment {
        return Time.today().add(new Time.Duration(-days * 86400));
    }

    // ---- fields -----------------------------------------------------------

    // Metric keys backing the configured graph pages, excluding "off" and
    // "load" (ctl/atl always come along), deduplicated.
    function selectedChartKeys() as Array {
        var keys = [];
        for (var i = 1; i <= IntervalsSettings.GRAPH_PAGES; i++) {
            var k = IntervalsSettings.graphType(i);
            if (!k.equals("off") && !k.equals("load") && keys.indexOf(k) < 0) {
                keys.add(k);
            }
        }
        return keys;
    }

    // ---- data-page sparklines ---------------------------------------------
    // Each data page is a table of metrics, each row with a short history.
    // The window matches INITIAL_HIST so a cold cache fills it in one fetch.
    const SPARK_DAYS = 30;

    // Metric keys shown on a data page, in priority order: a page shows the
    // first rows that have data, so the rarely-logged ones go last. The
    // view's row decoration (IntervalsWidgetView.rowFor) is keyed by these.
    function pageKeys(type as String) as Array<String> {
        if (type.equals("recovery")) {
            return ["restingHR", "hrv", "avgSleepingHR", "readiness",
                "hrvSDNN", "baevskySI"] as Array<String>;
        }
        if (type.equals("sleep")) {
            return ["sleepSecs", "sleepScore", "sleepQuality", "respiration",
                "spO2"] as Array<String>;
        }
        if (type.equals("body")) {
            return ["weight", "bodyFat", "vo2max", "systolic",
                "bloodGlucose"] as Array<String>;
        }
        if (type.equals("fuel")) {
            return ["steps", "kcalConsumed", "carbohydrates", "protein",
                "fatTotal", "hydrationVolume"] as Array<String>;
        }
        if (type.equals("feel")) {
            return ["fatigue", "soreness", "stress", "mood", "motivation",
                "injury"] as Array<String>;
        }
        return [] as Array<String>;
    }

    // Sparkline keys for the configured data pages, deduplicated and
    // excluding anything already kept as a chart series.
    function selectedSparkKeys() as Array {
        var charts = selectedChartKeys();
        var keys = [];
        for (var i = 1; i <= IntervalsSettings.DATA_PAGES; i++) {
            var page = pageKeys(IntervalsSettings.dataType(i));
            for (var j = 0; j < page.size(); j++) {
                var k = page[j];
                if (keys.indexOf(k) < 0 && charts.indexOf(k) < 0) {
                    keys.add(k);
                }
            }
        }
        return keys;
    }

    // Some chart keys are derived rather than raw wellness fields.
    function chartSourceField(key as String) as String {
        if (key.equals("sleepHours")) {
            return "sleepSecs";
        }
        if (key.equals("eftp")) {
            return "sportInfo";
        }
        return key;
    }

    // Everything one sync needs: tile fields plus the graph metrics.
    function unionFields() as String {
        var f = FIELDS_RECENT;
        var keys = selectedChartKeys();
        for (var i = 0; i < keys.size(); i++) {
            var src = chartSourceField(keys[i]);
            if (f.find(src) == null) {
                f += "," + src;
            }
        }
        return f;
    }

    // Per-day chart value for a key, with derivations; null when absent.
    function extractValue(r as Dictionary, key as String) {
        if (key.equals("sleepHours")) {
            var s = r["sleepSecs"];
            return s == null ? null : s.toFloat() / 3600;
        }
        if (key.equals("eftp")) {
            var si = r["sportInfo"];
            if (si instanceof Lang.Array) {
                for (var i = 0; i < si.size(); i++) {
                    var e = si[i];
                    if (e instanceof Lang.Dictionary && e["eftp"] != null) {
                        return e["eftp"].toFloat();
                    }
                }
            }
            return null;
        }
        var v = r[key];
        return v == null ? null : v.toFloat();
    }

    // ---- request windows --------------------------------------------------

    // Split the inclusive window [fromDaysBack .. toDaysBack] days before
    // today into request-sized chunks, oldest first. Most syncs produce one.
    function windowChunks(fromDaysBack as Number, toDaysBack as Number) as Array {
        var chunks = [];
        var start = -fromDaysBack;
        var last = -toDaysBack;
        while (start <= last) {
            var stop = start + (CHUNK_DAYS - 1) < last ? start + (CHUNK_DAYS - 1) : last;
            chunks.add([
                dateStr(Time.today().add(new Time.Duration(start * 86400))),
                dateStr(Time.today().add(new Time.Duration(stop * 86400)))
            ]);
            start = stop + 1;
        }
        return chunks;
    }

    const ERR_RECONNECT = "Reconnect intervals.icu";

    // Map makeWebRequest response codes to a short user-facing message.
    function errorText(code as Number) as String {
        if (code == 401 || code == 403) {
            return ERR_RECONNECT;
        }
        if (code == 404) {
            return "Bad athlete ID";
        }
        if (code == Communications.BLE_CONNECTION_UNAVAILABLE) {
            return "No phone";
        }
        return "Error " + code;
    }
}

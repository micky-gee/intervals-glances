import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Communications;
import Toybox.StringUtil;

// Request building and response parsing for the intervals.icu API.
// Included in the background context and (implicitly) the foreground app.
(:background)
module IntervalsApi {

    const RECENT_DAYS = 7;

    // Wellness fields shown on the metric pages. Asking the server to filter
    // keeps the JSON small enough for the background memory pool.
    const FIELDS_RECENT =
        "id,ctl,atl,rampRate," +
        "restingHR,hrv,hrvSDNN,avgSleepingHR,readiness,baevskySI," +
        "sleepSecs,sleepScore,sleepQuality,respiration,spO2," +
        "weight,bodyFat,vo2max,systolic,diastolic,bloodGlucose," +
        "steps,kcalConsumed,carbohydrates,protein,fatTotal,hydrationVolume," +
        "soreness,fatigue,stress,mood,motivation,injury";

    const CHART_SLOTS = 3;

    function wellnessUrl(athleteId as String) as String {
        return "https://intervals.icu/api/v1/athlete/" + athleteId + "/wellness";
    }

    function options(apiKey as String) as Dictionary {
        var b64 = StringUtil.convertEncodedString("API_KEY:" + apiKey, {
            :fromRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
            :toRepresentation => StringUtil.REPRESENTATION_STRING_BASE64
        });
        return {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => { "Authorization" => "Basic " + b64 },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
    }

    function dateStr(moment as Time.Moment) as String {
        var g = Gregorian.info(moment, Time.FORMAT_SHORT);
        return g.year.format("%04d") + "-" + g.month.format("%02d") + "-" + g.day.format("%02d");
    }

    function rangeParams(days as Number, fields as String) as Dictionary {
        var today = Time.today();
        var oldest = today.add(new Time.Duration(-(days - 1) * 86400));
        return {
            "oldest" => dateStr(oldest),
            "newest" => dateStr(today),
            "fields" => fields
        };
    }

    function recentParams() as Dictionary {
        return rangeParams(RECENT_DAYS, FIELDS_RECENT);
    }

    // All metric keys needing trend series: the line chart slots plus the
    // ring chart (excluding "off", deduplicated).
    function selectedChartKeys() as Array {
        var keys = [];
        for (var i = 1; i <= CHART_SLOTS; i++) {
            var k = IntervalsSettings.chartField(i);
            if (!k.equals("off") && keys.indexOf(k) < 0) {
                keys.add(k);
            }
        }
        var rk = IntervalsSettings.ringField();
        if (!rk.equals("off") && keys.indexOf(rk) < 0) {
            keys.add(rk);
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

    function trendFields() as String {
        var fields = ["id", "ctl", "atl"];
        var keys = selectedChartKeys();
        for (var i = 0; i < keys.size(); i++) {
            var src = chartSourceField(keys[i]);
            if (fields.indexOf(src) < 0) {
                fields.add(src);
            }
        }
        var f = "";
        for (var i = 0; i < fields.size(); i++) {
            f += (i > 0 ? "," : "") + fields[i];
        }
        return f;
    }

    // The full window in <=30 day chunks ([oldest, newest] date pairs,
    // oldest chunk first) so no single response trips the watch's
    // makeWebRequest size limit (error -402).
    function trendChunks() as Array {
        var days = IntervalsSettings.windowDays();
        var today = Time.today();
        var chunks = [];
        var start = -(days - 1);
        while (start <= 0) {
            var end = start + 29 < 0 ? start + 29 : 0;
            chunks.add([
                dateStr(today.add(new Time.Duration(start * 86400))),
                dateStr(today.add(new Time.Duration(end * 86400)))
            ]);
            start = end + 1;
        }
        return chunks;
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

    // Collapse a date-ascending list of wellness records into one dictionary
    // holding the most recent non-null value for every field.
    function summarize(records as Array) as Dictionary {
        var w = {};
        for (var i = 0; i < records.size(); i++) {
            var r = records[i];
            if (!(r instanceof Lang.Dictionary)) {
                continue;
            }
            var keys = r.keys();
            for (var k = 0; k < keys.size(); k++) {
                var key = keys[k];
                var v = r[key];
                if (v != null && !key.equals("id")) {
                    w[key] = v;
                }
            }
            if (r["ctl"] != null && r["id"] != null) {
                w["_date"] = r["id"];
            }
        }
        return w;
    }

    // Trend series accumulate across chunked requests: ctl/atl are
    // gap-filled; chart keys preserve nulls so sparse data charts as points.
    function initSeriesAcc() as Dictionary {
        var keys = selectedChartKeys();
        var acc = {
            "ctl" => [], "atl" => [],
            "_keys" => keys, "_lc" => 0.0, "_la" => 0.0
        };
        for (var i = 0; i < keys.size(); i++) {
            acc[keys[i]] = [];
        }
        return acc;
    }

    function appendSeries(acc as Dictionary, records as Array) as Void {
        var keys = acc["_keys"] as Array;
        var lastCtl = acc["_lc"] as Float;
        var lastAtl = acc["_la"] as Float;
        var ctl = acc["ctl"] as Array;
        var atl = acc["atl"] as Array;
        for (var i = 0; i < records.size(); i++) {
            var r = records[i];
            if (!(r instanceof Lang.Dictionary)) {
                continue;
            }
            var c = r["ctl"];
            var a = r["atl"];
            if (c != null) { lastCtl = c.toFloat(); }
            if (a != null) { lastAtl = a.toFloat(); }
            ctl.add(lastCtl);
            atl.add(lastAtl);
            for (var k = 0; k < keys.size(); k++) {
                (acc[keys[k]] as Array).add(extractValue(r, keys[k]));
            }
        }
        acc["_lc"] = lastCtl;
        acc["_la"] = lastAtl;
    }

    function finishSeries(acc as Dictionary) as Dictionary {
        acc.remove("_keys");
        acc.remove("_lc");
        acc.remove("_la");
        return acc;
    }

    // Map makeWebRequest response codes to a short user-facing message.
    function errorText(code as Number) as String {
        if (code == 401 || code == 403) {
            return "Bad API key";
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

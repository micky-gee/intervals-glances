import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;

// Merges fetched wellness records into the cached payload. Historical days are
// immutable, so a sync normally fetches only the last day or two and merges the
// result here instead of refetching the whole window.
//
// Cache shape (Storage "data"):
//   ts   epoch seconds of the last successful sync
//   hist days of history currently cached (see IntervalsData.histDays)
//   dn   day index of the newest day in every series array
//   w    summary: field -> most recent non-null value (+ "_date")
//   wi   field -> day index that value came from, for 7-day expiry
//   s    key -> array of daily values, oldest..newest, length == hist
(:background)
module IntervalsCache {

    // Tile values older than this stop being shown, matching the previous
    // "scan the last 7 days" behaviour.
    const SUMMARY_DAYS = 7;

    // Storage read that works from every scope (the background image doesn't
    // include the glance-annotated IntervalsData).
    function load() as Dictionary? {
        var d = Storage.getValue("data");
        return d instanceof Lang.Dictionary ? d : null;
    }

    function save(cache as Dictionary) as Void {
        Storage.setValue("data", cache);
    }

    // ---- auth failure backoff --------------------------------------------
    // A revoked key or token used to retry every hour forever, spending the
    // API budget on 401s. Back off hard until the user re-links.
    const BACKOFF_FIRST = 6 * 3600;
    const BACKOFF_MAX = 24 * 3600;

    // Cheap fingerprint of the credential in use, so a backoff earned by a
    // dead key can never suppress a freshly linked account.
    function credFingerprint() as Number {
        var s = IntervalsSettings.oauthToken();
        if (s == null) {
            s = IntervalsSettings.apiKey();
        }
        if (s == null) {
            return 0;
        }
        var h = s.length();
        var chars = s.toCharArray();
        for (var i = 0; i < chars.size(); i++) {
            h = (h * 31 + chars[i].toNumber()) % 1000000007;
        }
        return h;
    }

    function authBlocked() as Boolean {
        var until = Storage.getValue("authWait");
        if (!(until instanceof Lang.Number) || Time.now().value() >= until) {
            return false;
        }
        // Only the credential that actually failed stays blocked.
        var who = Storage.getValue("authWho");
        return who instanceof Lang.Number && who == credFingerprint();
    }

    function noteAuthFailure() as Void {
        var prev = Storage.getValue("authFails");
        var n = prev instanceof Lang.Number ? prev + 1 : 1;
        Storage.setValue("authFails", n);
        Storage.setValue("authWho", credFingerprint());
        Storage.setValue("authWait",
            Time.now().value() + (n <= 1 ? BACKOFF_FIRST : BACKOFF_MAX));
    }

    function clearAuthFailure() as Void {
        Storage.deleteValue("authFails");
        Storage.deleteValue("authWait");
        Storage.deleteValue("authWho");
    }

    // Rebuild the cache with `records` (any order, one per day) merged in.
    // Handles every case uniformly - appending today, backfilling older
    // history, or a full rebuild from an empty cache - by re-deriving each
    // series array against the target day range.
    function merge(cache as Dictionary?, records as Array, histDays as Number) as Dictionary {
        var today = IntervalsApi.todayIdx();

        // Index the incoming batch by day.
        var byDay = {};
        var newest = null;
        for (var i = 0; i < records.size(); i++) {
            var r = records[i];
            if (!(r instanceof Lang.Dictionary)) {
                continue;
            }
            var idx = IntervalsApi.dayIdxOfDate(r["id"]);
            if (idx != null) {
                byDay[idx] = r;
                if (newest == null || idx > newest) { newest = idx; }
            }
        }

        var old = cache instanceof Lang.Dictionary ? cache : {};
        var oldS = old["s"] instanceof Lang.Dictionary ? old["s"] as Dictionary : {};
        var oldDn = old["dn"] instanceof Lang.Number ? old["dn"] as Number : null;

        // The newest cached day is today unless we somehow only have older
        // data (no response yet today); never move the window backwards.
        var dn = today;
        if (oldDn != null && oldDn > dn) { dn = oldDn; }

        var keys = IntervalsApi.selectedChartKeys();
        var seriesKeys = ["ctl", "atl"] as Array<String>;
        for (var i = 0; i < keys.size(); i++) {
            seriesKeys.add(keys[i]);
        }

        var s = {};
        for (var k = 0; k < seriesKeys.size(); k++) {
            var key = seriesKeys[k];
            var prev = oldS[key] instanceof Lang.Array ? oldS[key] as Array : null;
            var prevLen = prev != null ? prev.size() : 0;
            var out = new Array<Float?>[histDays];
            var carry = null;              // forward-fill for ctl/atl
            var fill = key.equals("ctl") || key.equals("atl");

            for (var i = 0; i < histDays; i++) {
                var day = dn - (histDays - 1 - i);
                var v = null;

                var rec = byDay[day];
                if (rec != null) {
                    v = IntervalsApi.extractValue(rec, key);
                }
                if (v == null && prev != null && oldDn != null) {
                    // Same day in the previous cache, if it held one.
                    var pi = prevLen - 1 - (oldDn - day);
                    if (pi >= 0 && pi < prevLen) {
                        v = prev[pi];
                    }
                }
                if (fill) {
                    if (v == null) { v = carry; }
                    else { carry = v; }
                }
                out[i] = v;
            }

            // ctl/atl must never be null (the charts assume numbers); fill any
            // leading gap with the first known value, or zero for a cold cache.
            if (fill) {
                var first = null;
                for (var i = 0; i < histDays && first == null; i++) {
                    first = out[i];
                }
                if (first == null) { first = 0.0; }
                for (var i = 0; i < histDays; i++) {
                    if (out[i] == null) { out[i] = first; }
                }
            }
            s[key] = out;
        }

        // Summary: newest non-null value per field, with the day it came from
        // so it can expire after SUMMARY_DAYS.
        var w = old["w"] instanceof Lang.Dictionary ? old["w"] as Dictionary : {};
        var wi = old["wi"] instanceof Lang.Dictionary ? old["wi"] as Dictionary : {};
        var days = byDay.keys();
        days = sortAsc(days);
        for (var d = 0; d < days.size(); d++) {
            var day = days[d] as Number;
            var rec = byDay[day] as Dictionary;
            var fields = rec.keys();
            for (var f = 0; f < fields.size(); f++) {
                var name = fields[f];
                var v = rec[name];
                if (v == null || name.equals("id")) {
                    continue;
                }
                var seen = wi[name];
                if (!(seen instanceof Lang.Number) || day >= seen) {
                    w[name] = v;
                    wi[name] = day;
                }
            }
            if (rec["ctl"] != null && rec["id"] != null) {
                w["_date"] = rec["id"];
            }
        }
        expire(w, wi, today);

        return {
            "ts" => Time.now().value(),
            "hist" => histDays,
            "dn" => dn,
            "w" => w,
            "wi" => wi,
            "s" => s
        };
    }

    // Drop tile values that have aged out of the summary window.
    function expire(w as Dictionary, wi as Dictionary, today as Number) as Void {
        var names = wi.keys();
        for (var i = 0; i < names.size(); i++) {
            var name = names[i];
            var day = wi[name];
            if (day instanceof Lang.Number && today - day >= SUMMARY_DAYS) {
                wi.remove(name);
                w.remove(name);
            }
        }
    }

    function sortAsc(a as Array) as Array {
        // Small arrays (days in one batch); insertion sort keeps it simple.
        for (var i = 1; i < a.size(); i++) {
            var v = a[i];
            var j = i - 1;
            while (j >= 0 && a[j] > v) {
                a[j + 1] = a[j];
                j--;
            }
            a[j + 1] = v;
        }
        return a;
    }
}

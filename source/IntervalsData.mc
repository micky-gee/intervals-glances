import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;

// Cached-data access plus formatting helpers. Needed by both the glance
// and the full-screen views, so everything here is glance-annotated.
(:glance)
module IntervalsData {

    function data() as Dictionary? {
        var d = Storage.getValue("data");
        if (d instanceof Lang.Dictionary) {
            return d;
        }
        return null;
    }

    function wellness() as Dictionary? {
        var d = data();
        if (d != null && d["w"] instanceof Lang.Dictionary) {
            return d["w"];
        }
        return null;
    }

    // Trend series array for a key ("ctl", "atl", or a chart metric).
    function series(key as String) as Array? {
        var d = data();
        if (d != null && d["s"] instanceof Lang.Dictionary) {
            var s = (d["s"] as Dictionary)[key];
            if (s instanceof Lang.Array && s.size() >= 2) {
                return s;
            }
        }
        return null;
    }

    function lastError() as String? {
        var e = Storage.getValue("err");
        if (e instanceof Lang.String) {
            return e;
        }
        return null;
    }

    // Seconds since the last successful sync, or null if never synced.
    function ageSecs() as Number? {
        var d = data();
        if (d != null && d["ts"] instanceof Lang.Number) {
            var age = Time.now().value() - d["ts"];
            return age < 0 ? 0 : age;
        }
        return null;
    }

    function ageText() as String {
        var age = ageSecs();
        if (age == null) {
            return "never";
        }
        if (age < 60) {
            return "now";
        }
        if (age < 3600) {
            return (age / 60).format("%d") + "m";
        }
        if (age < 86400) {
            return (age / 3600).format("%d") + "h";
        }
        return (age / 86400).format("%d") + "d";
    }

    // Format a possibly-null numeric value with the given decimal places.
    function fmt(v, dec as Number) as String {
        if (v == null) {
            return "--";
        }
        if (v instanceof Lang.Float || v instanceof Lang.Double) {
            return v.format("%." + dec + "f");
        }
        if (dec == 0) {
            return v.format("%d");
        }
        return v.toFloat().format("%." + dec + "f");
    }

    function fmtSleep(secs) as String {
        if (secs == null) {
            return "--";
        }
        var h = secs / 3600;
        var m = (secs % 3600) / 60;
        return h.format("%d") + "h" + m.format("%02d");
    }

    // Form (TSB) = ctl - atl. Returns null when no data.
    function form() as Float? {
        var w = wellness();
        if (w == null || w["ctl"] == null || w["atl"] == null) {
            return null;
        }
        return w["ctl"].toFloat() - w["atl"].toFloat();
    }

    // Form as a percentage of fitness, the scale intervals.icu uses for
    // its colored form zones.
    function formPercent() as Float? {
        var w = wellness();
        if (w == null || w["ctl"] == null || w["atl"] == null) {
            return null;
        }
        var ctl = w["ctl"].toFloat();
        if (ctl <= 0) {
            return 0.0;
        }
        return (ctl - w["atl"].toFloat()) / ctl * 100;
    }

    // intervals.icu form zones (form as % of fitness).
    function formZoneLabel() as String {
        var p = formPercent();
        if (p == null) {
            return "";
        }
        if (p > 20) { return "Transition"; }
        if (p > 5) { return "Fresh"; }
        if (p > -10) { return "Grey zone"; }
        if (p > -30) { return "Optimal"; }
        return "High risk";
    }

    function formZoneColor() as Number {
        var p = formPercent();
        if (p == null) {
            return Graphics.COLOR_LT_GRAY;
        }
        if (p > 20) { return 0xAAAAAA; }   // transition - grey
        if (p > 5) { return 0x55AAFF; }    // fresh - blue
        if (p > -10) { return 0xCCCCCC; }  // grey zone
        if (p > -30) { return 0x00CC66; }  // optimal - green
        return 0xFF4444;                   // high risk - red
    }

    function formText() as String {
        if (IntervalsSettings.formAsPercent()) {
            var p = formPercent();
            if (p == null) {
                return "--";
            }
            return (p >= 0 ? "+" : "") + p.format("%.0f") + "%";
        }
        var f = form();
        if (f == null) {
            return "--";
        }
        return (f >= 0 ? "+" : "") + f.format("%.0f");
    }
}

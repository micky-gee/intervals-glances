import Toybox.Application;
import Toybox.Lang;

// User settings, readable from foreground, glance and background contexts.
(:background :glance)
module IntervalsSettings {

    function apiKey() as String? {
        var v = Application.Properties.getValue("apiKey");
        if (v instanceof Lang.String && v.length() > 0) {
            return v;
        }
        return null;
    }

    function athleteId() as String {
        var v = Application.Properties.getValue("athleteId");
        if (v instanceof Lang.String && v.length() > 0) {
            return v;
        }
        return "0"; // 0 = the athlete that owns the API key
    }

    function formAsPercent() as Boolean {
        var v = Application.Properties.getValue("formAsPercent");
        return v == true;
    }

    const GRAPH_PAGES = 4;
    const DATA_PAGES = 4;

    // Index order must match the graph/data list entries in settings.xml.
    const GRAPH_TYPES = [
        "off", "load", "hrv", "hrvSDNN", "restingHR", "avgSleepingHR",
        "rampRate", "eftp", "weight", "bodyFat", "vo2max", "sleepScore",
        "sleepHours", "readiness", "steps", "spO2", "respiration",
        "baevskySI", "kcalConsumed"
    ] as Array<String>;
    const DATA_TYPES = [
        "off", "form", "recovery", "sleep", "body", "fuel", "feel", "status"
    ] as Array<String>;

    // Settings synced from the phone sometimes arrive as Strings or Floats
    // rather than Numbers; coerce before range-checking.
    function asNumber(v) as Number? {
        if (v instanceof Lang.Number) {
            return v;
        }
        if (v instanceof Lang.Float || v instanceof Lang.Double
            || v instanceof Lang.String) {
            return v.toNumber();
        }
        return null;
    }

    // Graph page n (1..GRAPH_PAGES): chart type key ("off", "load", or a
    // metric), and whether it renders round (vs rectangular).
    function graphType(n as Number) as String {
        var v = asNumber(Application.Properties.getValue("graph" + n + "Type"));
        if (v != null && v >= 0 && v < GRAPH_TYPES.size()) {
            return GRAPH_TYPES[v];
        }
        return "off";
    }

    function graphRound(n as Number) as Boolean {
        return Application.Properties.getValue("graph" + n + "Round") != false;
    }

    // Data page n (1..DATA_PAGES): tile page key, or "off".
    function dataType(n as Number) as String {
        var v = asNumber(Application.Properties.getValue("data" + n + "Type"));
        if (v != null && v >= 0 && v < DATA_TYPES.size()) {
            return DATA_TYPES[v];
        }
        return "off";
    }

    // Glance content: 0 = fit+fat+form, 1 = fitness, 2 = fatigue, 3 = form.
    function glanceMode() as Number {
        var v = asNumber(Application.Properties.getValue("glanceMode"));
        if (v != null && v >= 0 && v <= 3) {
            return v;
        }
        return 0;
    }
}

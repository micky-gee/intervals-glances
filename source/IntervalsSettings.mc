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

    function windowDays() as Number {
        var v = asNumber(Application.Properties.getValue("windowDays"));
        if (v != null && v >= 14 && v <= 365) {
            return v;
        }
        return 90;
    }

    // Index order must match the chart list entries in settings.xml.
    const CHART_KEYS = [
        "off", "hrv", "hrvSDNN", "restingHR", "avgSleepingHR", "rampRate",
        "eftp", "weight", "bodyFat", "vo2max", "sleepScore", "sleepHours",
        "readiness", "steps", "spO2", "respiration", "baevskySI", "kcalConsumed"
    ] as Array<String>;

    // Chart slot n (1..3) -> selected metric key, or "off".
    function chartField(n as Number) as String {
        var v = asNumber(Application.Properties.getValue("chart" + n));
        if (v != null && v >= 0 && v < CHART_KEYS.size()) {
            return CHART_KEYS[v];
        }
        return "off";
    }

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

    // Glance content: 0 = fit+fat+form, 1 = fitness, 2 = fatigue, 3 = form.
    function glanceMode() as Number {
        var v = asNumber(Application.Properties.getValue("glanceMode"));
        if (v != null && v >= 0 && v <= 3) {
            return v;
        }
        return 0;
    }

    // Per-page visibility toggles ("pageRecovery" etc.), default shown.
    function pageEnabled(prop as String) as Boolean {
        return Application.Properties.getValue(prop) != false;
    }

    // Render the load and metric chart pages radially (vs rectangular).
    function roundCharts() as Boolean {
        var v = Application.Properties.getValue("roundCharts");
        return v != false;
    }

    // The radial ring chart's metric key, or "off".
    function ringField() as String {
        var v = asNumber(Application.Properties.getValue("chartRing"));
        if (v != null && v >= 0 && v < CHART_KEYS.size()) {
            return CHART_KEYS[v];
        }
        return "off";
    }
}

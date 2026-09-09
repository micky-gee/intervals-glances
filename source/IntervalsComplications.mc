import Toybox.Complications;
import Toybox.Lang;
import Toybox.System;

// Publishes one complication carrying fitness/fatigue/form as a single string,
// so a watch face can show all three without the app being open.
//
// One complication rather than three: the watch's complication picker only ever
// offers the first one an app declares, so three separate values could not all
// be chosen. Packing them into one string sidesteps that.
//
// This only reads the cache the sync already maintains, so it costs no extra
// API requests. Background-annotated because the background sync publishes too,
// which is what keeps a watch face current between app opens.
(:background)
module IntervalsComplications {

    // Stable across versions: a subscribing watch face stores the id it picked.
    const ID_DATA = 0;

    function publish() as Void {
        if (!(Toybox has :Complications)) {
            return;
        }
        var text = summary();
        try {
            // A string value must be published without units or ranges - the
            // framework rejects either one alongside it.
            Complications.updateComplication(ID_DATA, { :value => text });
            System.println("comp: " + text);
        } catch (e) {
            System.println("comp: publish failed");
        }
    }

    // "fitness/fatigue/form", e.g. "31/15/+16" - whole numbers, matching what
    // the app's own pages show, with form signed and carrying % when the form
    // scale is set to percent so a complication never disagrees with the app.
    function summary() as String {
        var c = IntervalsCache.load();
        if (!(c instanceof Lang.Dictionary) || !(c["w"] instanceof Lang.Dictionary)) {
            return "--";
        }
        var w = c["w"] as Dictionary;
        var ctl = w["ctl"];
        var atl = w["atl"];
        if (ctl == null || atl == null) {
            return "--";
        }
        var f = ctl.toFloat();
        var a = atl.toFloat();
        var pct = IntervalsSettings.formAsPercent();
        var form = pct ? (f <= 0 ? 0.0 : (f - a) / f * 100) : f - a;
        var n = whole(form);
        return whole(f).format("%d") + "/" + whole(a).format("%d")
            + "/" + (n >= 0 ? "+" : "") + n.format("%d") + (pct ? "%" : "");
    }

    // Rounds half away from zero, so -4.6 reads -5 rather than -4.
    function whole(v as Float) as Number {
        return (v >= 0 ? v + 0.5 : v - 0.5).toNumber();
    }
}

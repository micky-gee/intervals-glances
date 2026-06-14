import Toybox.Lang;

// Page order is dynamic: chart pages appear for each configured chart slot.
module IntervalsPages {

    function list() as Array {
        // The load page is always present so the list can never be empty.
        var p = [];
        if (IntervalsSettings.pageEnabled("pageForm")) { p.add("form"); }
        p.add("load");
        for (var i = 1; i <= IntervalsApi.CHART_SLOTS; i++) {
            var k = IntervalsSettings.chartField(i);
            if (!k.equals("off") && p.indexOf("chart:" + k) < 0) {
                p.add("chart:" + k);
            }
        }
        var rk = IntervalsSettings.ringField();
        if (!rk.equals("off")) {
            p.add("ring:" + rk);
        }
        if (IntervalsSettings.pageEnabled("pageRecovery")) { p.add("recovery"); }
        if (IntervalsSettings.pageEnabled("pageSleep")) { p.add("sleep"); }
        if (IntervalsSettings.pageEnabled("pageBody")) { p.add("body"); }
        if (IntervalsSettings.pageEnabled("pageFuel")) { p.add("fuel"); }
        if (IntervalsSettings.pageEnabled("pageFeel")) { p.add("feel"); }
        if (IntervalsSettings.pageEnabled("pageStatus")) { p.add("status"); }
        return p;
    }

    function count() as Number {
        return list().size();
    }

    function idAt(page as Number) as String {
        var l = list();
        return l[page < l.size() ? page : 0];
    }

    // Time-series pages that the zoom control applies to.
    function isChart(id as String) as Boolean {
        return id.equals("load") || id.find("chart:") == 0 || id.find("ring:") == 0;
    }
}

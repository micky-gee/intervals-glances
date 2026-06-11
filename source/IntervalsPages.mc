import Toybox.Lang;

// Page order is dynamic: chart pages appear for each configured chart slot.
module IntervalsPages {

    function list() as Array {
        var p = ["form", "load"];
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
        p.add("recovery");
        p.add("sleep");
        p.add("body");
        p.add("fuel");
        p.add("feel");
        p.add("status");
        return p;
    }

    function count() as Number {
        return list().size();
    }
}

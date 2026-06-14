import Toybox.Lang;

// Page order is dynamic: up to 4 graph pages then up to 4 data pages, each
// skipped when set to "off". Descriptors are self-describing so the view
// needs no settings lookup:
//   graph -> "g:<r|s>:<type>"   (r = round, s = square/rectangular)
//   data  -> "d:<type>"
//   none  -> "none"             (sentinel so the list is never empty)
module IntervalsPages {

    function list() as Array {
        var p = [];
        for (var i = 1; i <= IntervalsSettings.GRAPH_PAGES; i++) {
            var t = IntervalsSettings.graphType(i);
            if (!t.equals("off")) {
                p.add("g:" + (IntervalsSettings.graphRound(i) ? "r" : "s") + ":" + t);
            }
        }
        for (var i = 1; i <= IntervalsSettings.DATA_PAGES; i++) {
            var t = IntervalsSettings.dataType(i);
            if (!t.equals("off")) {
                p.add("d:" + t);
            }
        }
        if (p.size() == 0) {
            p.add("none");
        }
        return p;
    }

    function count() as Number {
        return list().size();
    }

    function idAt(page as Number) as String {
        var l = list();
        return l[page < l.size() ? page : 0];
    }

    // Graph pages are the time-series charts the zoom control applies to.
    function isChart(id as String) as Boolean {
        return id.find("g:") == 0;
    }
}

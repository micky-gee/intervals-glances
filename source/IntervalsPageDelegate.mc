import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Normal mode: UP/DOWN (or swipe) cycles pages; START opens the zoom control
// on chart pages, or forces a sync elsewhere.
// Zoom mode (chart pages only): UP/+ zooms in (fewer days), DOWN/- zooms out
// (more days), touch taps the on-screen +/- halves, START or BACK closes it.
class IntervalsPageDelegate extends WatchUi.BehaviorDelegate {

    hidden var _page as Number;

    function initialize(page as Number) {
        BehaviorDelegate.initialize();
        _page = page;
    }

    // DOWN button (nextPage) zooms out (-, more days).
    function onNextPage() as Boolean {
        if (IntervalsRefresh.zoomActive) {
            IntervalsData.zoomOut();
            WatchUi.requestUpdate();
            return true;
        }
        var n = IntervalsPages.count();
        switchTo((_page + 1) % n, WatchUi.SLIDE_UP);
        return true;
    }

    // UP button (previousPage) zooms in (+, fewer days).
    function onPreviousPage() as Boolean {
        if (IntervalsRefresh.zoomActive) {
            IntervalsData.zoomIn();
            WatchUi.requestUpdate();
            return true;
        }
        var n = IntervalsPages.count();
        switchTo((_page + n - 1) % n, WatchUi.SLIDE_DOWN);
        return true;
    }

    function onSelect() as Boolean {
        if (IntervalsPages.isChart(IntervalsPages.idAt(_page))) {
            IntervalsRefresh.zoomActive = !IntervalsRefresh.zoomActive;
        } else {
            IntervalsRefresh.start();
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() as Boolean {
        if (IntervalsRefresh.zoomActive) {
            IntervalsRefresh.zoomActive = false;
            WatchUi.requestUpdate();
            return true; // consume so the widget doesn't close
        }
        return false; // default: leave the widget
    }

    // Touch devices: tap the upper half (+) to zoom in, lower half (-) to
    // zoom out, matching the on-screen glyph positions.
    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        if (!IntervalsRefresh.zoomActive) {
            return false;
        }
        var c = evt.getCoordinates();
        if (c[1] < (System.getDeviceSettings().screenHeight / 2)) {
            IntervalsData.zoomIn();
        } else {
            IntervalsData.zoomOut();
        }
        WatchUi.requestUpdate();
        return true;
    }

    hidden function switchTo(page as Number, transition as WatchUi.SlideType) as Void {
        WatchUi.switchToView(new IntervalsWidgetView(page),
            new IntervalsPageDelegate(page), transition);
    }
}

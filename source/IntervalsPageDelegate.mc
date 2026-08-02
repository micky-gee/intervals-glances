import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Normal mode: UP/DOWN (or swipe) cycles pages; START opens the zoom control
// on chart pages, starts the OAuth flow when not connected (or on the
// migration page), or forces a sync elsewhere.
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
            if (IntervalsData.needsBackfill()) {
                // Zoomed past the cached span: fetch the older days once.
                IntervalsRefresh.backfillHistory();
            }
            WatchUi.requestUpdate();
            return true;
        }
        if (snoozeMigration()) {
            // The migrate page just left the list; the old page 1 is now 0.
            switchTo(0, WatchUi.SLIDE_UP);
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
        if (snoozeMigration()) {
            switchTo(IntervalsPages.count() - 1, WatchUi.SLIDE_DOWN);
            return true;
        }
        var n = IntervalsPages.count();
        switchTo((_page + n - 1) % n, WatchUi.SLIDE_DOWN);
        return true;
    }

    function onSelect() as Boolean {
        var id = IntervalsPages.idAt(_page);
        if (!IntervalsSettings.isConnected() || id.equals("migrate")) {
            // First-run connect, or the migration nudge's connect action.
            IntervalsAuth.connect();
        } else if (id.equals("d:status") && IntervalsSettings.oauthToken() == null) {
            // The status page is the always-available way to link: legacy key
            // users can reach it even while the migration nudge is snoozed,
            // and it doubles as the recovery path for a revoked token.
            IntervalsAuth.connect();
        } else if (IntervalsPages.isChart(id)) {
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
        // Deliberately does NOT snooze the migration nudge: BACK (and the
        // system-driven exits that also arrive here) would otherwise hide it
        // for days without the user ever choosing "later". Only an explicit
        // UP/DOWN off the page snoozes it.
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

    // If the user is leaving the migration page, snooze the nudge (it drops
    // out of the page list). Returns true when that happened.
    hidden function snoozeMigration() as Boolean {
        if (IntervalsPages.idAt(_page).equals("migrate")) {
            IntervalsData.migrationSnooze();
            return true;
        }
        return false;
    }

    hidden function switchTo(page as Number, transition as WatchUi.SlideType) as Void {
        WatchUi.switchToView(new IntervalsWidgetView(page),
            new IntervalsPageDelegate(page), transition);
    }
}

import Toybox.Lang;
import Toybox.WatchUi;

// UP/DOWN (or swipe) cycles pages; START forces a sync.
class IntervalsPageDelegate extends WatchUi.BehaviorDelegate {

    hidden var _page as Number;

    function initialize(page as Number) {
        BehaviorDelegate.initialize();
        _page = page;
    }

    function onNextPage() as Boolean {
        var n = IntervalsPages.count();
        switchTo((_page + 1) % n, WatchUi.SLIDE_UP);
        return true;
    }

    function onPreviousPage() as Boolean {
        var n = IntervalsPages.count();
        switchTo((_page + n - 1) % n, WatchUi.SLIDE_DOWN);
        return true;
    }

    function onSelect() as Boolean {
        IntervalsRefresh.start();
        WatchUi.requestUpdate();
        return true;
    }

    hidden function switchTo(page as Number, transition as WatchUi.SlideType) as Void {
        WatchUi.switchToView(new IntervalsWidgetView(page),
            new IntervalsPageDelegate(page), transition);
    }
}

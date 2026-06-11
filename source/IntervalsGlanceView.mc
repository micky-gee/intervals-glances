import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

(:glance)
class IntervalsGlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Title line: app name plus data age.
        dc.setColor(0x55AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, h / 5, Graphics.FONT_GLANCE,
            "INTERVALS", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var age = IntervalsData.ageText();
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w, h / 5, Graphics.FONT_GLANCE,
            age, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        var wd = IntervalsData.wellness();
        if (wd == null) {
            var err = IntervalsData.lastError();
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(0, h * 2 / 3, Graphics.FONT_GLANCE,
                err != null ? err : "Waiting for sync...",
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        // Metric line: form (colored by zone), fitness, fatigue.
        var y = h * 2 / 3;
        var x = 0;

        dc.setColor(IntervalsData.formZoneColor(), Graphics.COLOR_TRANSPARENT);
        var formStr = "Form " + IntervalsData.formText();
        dc.drawText(x, y, Graphics.FONT_GLANCE_NUMBER, formStr,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x += dc.getTextWidthInPixels(formStr, Graphics.FONT_GLANCE_NUMBER) + w / 14;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var fitStr = "Fit " + IntervalsData.fmt(wd["ctl"], 0);
        dc.drawText(x, y, Graphics.FONT_GLANCE_NUMBER, fitStr,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x += dc.getTextWidthInPixels(fitStr, Graphics.FONT_GLANCE_NUMBER) + w / 14;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_GLANCE_NUMBER,
            "Fat " + IntervalsData.fmt(wd["atl"], 0),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

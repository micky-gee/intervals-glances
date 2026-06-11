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

        // The glance band sits high on the round face, so keep content
        // inside the chord with side insets.
        var x0 = w * 11 / 100;
        var x1 = w * 92 / 100;

        var hy = h * 13 / 100;
        var wd = IntervalsData.wellness();
        if (wd == null) {
            dc.setColor(0x55AAFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x0, hy, Graphics.FONT_GLANCE,
                "INTERVALS", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            var err = IntervalsData.lastError();
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x0, h * 2 / 3, Graphics.FONT_GLANCE,
                err != null ? err : "Waiting for sync...",
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var ctl = IntervalsData.series("ctl");
        var atl = IntervalsData.series("atl");
        if (ctl != null && atl != null) {
            // Header: form readout left (the number that matters), age right.
            dc.setColor(IntervalsData.formZoneColor(), Graphics.COLOR_TRANSPARENT);
            dc.drawText(x0, hy, Graphics.FONT_GLANCE,
                "Form " + IntervalsData.formText(),
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x1, hy, Graphics.FONT_GLANCE, IntervalsData.ageText(),
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            drawMiniLoad(dc, ctl, atl, x0, x1, h * 34 / 100, h * 94 / 100);
            return;
        }

        dc.setColor(0x55AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0, hy, Graphics.FONT_GLANCE,
            "INTERVALS", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // No series cached yet: fall back to the text row.
        var y = h * 2 / 3;
        var x = x0;
        dc.setColor(IntervalsData.formZoneColor(), Graphics.COLOR_TRANSPARENT);
        var formStr = "Form " + IntervalsData.formText();
        dc.drawText(x, y, Graphics.FONT_GLANCE_NUMBER, formStr,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x += dc.getTextWidthInPixels(formStr, Graphics.FONT_GLANCE_NUMBER) + w / 14;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_GLANCE_NUMBER,
            "Fit " + IntervalsData.fmt(wd["ctl"], 0),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Compact banded CTL/ATL chart sized for the glance. Kept self-contained
    // so the full chart module stays out of the small glance memory pool.
    hidden function drawMiniLoad(dc as Dc, ctl as Array, atl as Array,
            x0 as Number, x1 as Number, y0 as Number, y1 as Number) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        var n = ctl.size();
        if (n < 2) {
            return;
        }

        // Display range: data plus the form-zone band envelope.
        var ctlMin = ctl[0].toFloat();
        var ctlMax = ctlMin;
        var lo = ctlMin;
        var hi = ctlMin;
        for (var i = 0; i < n; i++) {
            var c = ctl[i].toFloat();
            var a = atl[i].toFloat();
            if (c < ctlMin) { ctlMin = c; }
            if (c > ctlMax) { ctlMax = c; }
            if (c < lo) { lo = c; }
            if (a < lo) { lo = a; }
            if (c > hi) { hi = c; }
            if (a > hi) { hi = a; }
        }
        if (ctlMin * 0.78 < lo) { lo = ctlMin * 0.78; }
        if (ctlMax * 1.38 > hi) { hi = ctlMax * 1.38; }
        var pad = (hi - lo) * 0.03;
        lo -= pad;
        hi += pad;
        if (lo < 0) { lo = 0.0; }
        if (hi - lo < 1) { hi = lo + 1; }
        var scale = (y1 - y0).toFloat() / (hi - lo);

        // Zone bands, in coarse 3px columns to keep the glance light.
        var muls = [0.80, 0.95, 1.10, 1.30] as Array<Float>;
        var fills = [0x29293D, 0x14324D, 0x262626, 0x103D24, 0x451519] as Array<Number>;
        dc.setPenWidth(3);
        for (var x = x0; x <= x1; x += 3) {
            var t = (x - x0).toFloat() / (x1 - x0) * (n - 1);
            var i = t.toNumber();
            var i2 = i + 1 < n ? i + 1 : i;
            var fr = t - i;
            var c = ctl[i].toFloat() * (1 - fr) + ctl[i2].toFloat() * fr;

            var prevY = y1;
            for (var z = 0; z < 5; z++) {
                var bandTop = z < 4 ? c * muls[z] : hi;
                var yTop = y1 - ((bandTop - lo) * scale).toNumber();
                if (yTop < y0) { yTop = y0; }
                if (yTop < prevY) {
                    dc.setColor(fills[z], Graphics.COLOR_TRANSPARENT);
                    dc.drawLine(x, prevY, x, yTop);
                    prevY = yTop;
                }
            }
        }

        drawMiniLine(dc, atl, lo, scale, x0, x1, y0, y1, 0xCC66FF, 2);
        drawMiniLine(dc, ctl, lo, scale, x0, x1, y0, y1, 0x4DA6FF, 3);
    }

    hidden function drawMiniLine(dc as Dc, series as Array, lo as Float,
            scale as Float, x0 as Number, x1 as Number, y0 as Number,
            y1 as Number, color as Number, pen as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pen);
        var n = series.size();
        var px = x0;
        var py = clampY(y1 - ((series[0].toFloat() - lo) * scale).toNumber(), y0, y1);
        for (var i = 1; i < n; i++) {
            var x = x0 + (x1 - x0) * i / (n - 1);
            var y = clampY(y1 - ((series[i].toFloat() - lo) * scale).toNumber(), y0, y1);
            dc.drawLine(px, py, x, y);
            px = x;
            py = y;
        }
        dc.setPenWidth(1);
    }

    hidden function clampY(y as Number, y0 as Number, y1 as Number) as Number {
        if (y < y0) { return y0; }
        if (y > y1) { return y1; }
        return y;
    }
}

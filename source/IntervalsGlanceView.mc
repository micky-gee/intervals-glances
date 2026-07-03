import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

(:glance)
class IntervalsGlanceView extends WatchUi.GlanceView {

    // Form-zone band fills, kept in sync with IntervalsCharts.ZONE_FILLS
    // (duplicated so the chart module stays out of the glance memory pool).
    const FILLS = [0x44445C, 0x1F66A3, 0x2E2E2E, 0x1E7A45, 0x4D1A20] as Array<Number>;
    const THRESHOLDS = [20.0, 5.0, -10.0, -30.0] as Array<Float>;
    const CTL_COLOR = 0x4DA6FF;
    const ATL_COLOR = 0xCC66FF;

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
            var mode = IntervalsSettings.glanceMode();

            // Header: the mode's headline number left, age right.
            var head;
            var headColor;
            if (mode == 1) {
                head = "Fit " + IntervalsData.fmt(wd["ctl"], 0);
                headColor = CTL_COLOR;
            } else if (mode == 2) {
                head = "Fat " + IntervalsData.fmt(wd["atl"], 0);
                headColor = ATL_COLOR;
            } else {
                head = "Form " + IntervalsData.formText();
                headColor = IntervalsData.formZoneColor();
            }
            dc.setColor(headColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x0, hy, Graphics.FONT_GLANCE, head,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x1, hy, Graphics.FONT_GLANCE, IntervalsData.ageText(),
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

            // The chart can run nearly to the carousel focus bar; only the
            // text needs the bigger inset.
            var y0 = h * 34 / 100;
            var y1 = h * 94 / 100;
            var gx0 = w * 3 / 100;
            if (mode == 3) {
                drawMiniForm(dc, ctl, atl, gx0, x1, y0, y1);
            } else {
                drawMiniLoad(dc, ctl, atl, mode, gx0, x1, y0, y1);
            }
            return;
        }

        // No series cached yet: fall back to the text row.
        dc.setColor(0x55AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0, hy, Graphics.FONT_GLANCE,
            "INTERVALS", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
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

    // Banded CTL/ATL chart. mode 0 draws both lines, 1 only CTL, 2 only ATL.
    hidden function drawMiniLoad(dc as Dc, ctl as Array, atl as Array,
            mode as Number, x0 as Number, x1 as Number, y0 as Number,
            y1 as Number) as Void {
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
        dc.setPenWidth(3);
        for (var x = x0; x <= x1; x += 3) {
            var t = (x - x0).toFloat() / (x1 - x0) * (n - 1);
            var i = t.toNumber();
            var i2 = i + 1 < n ? i + 1 : i;
            var fr = t - i;
            var c = ctl[i].toFloat() * (1 - fr) + ctl[i2].toFloat() * fr;

            var prevY = y1;
            for (var z = 0; z < 5; z++) {
                var bandTop = z < 4 ? c - THRESHOLDS[z] : hi;
                var yTop = y1 - ((bandTop - lo) * scale).toNumber();
                if (yTop < y0) { yTop = y0; }
                if (yTop < prevY) {
                    dc.setColor(FILLS[z], Graphics.COLOR_TRANSPARENT);
                    dc.drawLine(x, prevY, x, yTop);
                    prevY = yTop;
                }
            }
        }

        if (mode != 1) {
            drawMiniLine(dc, atl, lo, scale, x0, x1, y0, y1, ATL_COLOR, mode == 2 ? 3 : 2);
        }
        if (mode != 2) {
            drawMiniLine(dc, ctl, lo, scale, x0, x1, y0, y1, CTL_COLOR, 3);
        }
    }

    // Form (ctl - atl) over its own zone bands; in form space the bands run
    // high-risk at the bottom up to transition at the top.
    hidden function drawMiniForm(dc as Dc, ctl as Array, atl as Array,
            x0 as Number, x1 as Number, y0 as Number, y1 as Number) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        var n = ctl.size();
        if (n < 2) {
            return;
        }

        var form = new Array<Float>[n];
        var ctlMax = ctl[0].toFloat();
        var lo = null;
        var hi = null;
        for (var i = 0; i < n; i++) {
            var c = ctl[i].toFloat();
            if (c > ctlMax) { ctlMax = c; }
            var f = c - atl[i].toFloat();
            form[i] = f;
            if (lo == null || f < lo) { lo = f; }
            if (hi == null || f > hi) { hi = f; }
        }
        if (-35.0 < lo) { lo = -35.0; }
        if (25.0 > hi) { hi = 25.0; }
        var pad = (hi - lo) * 0.03;
        lo -= pad;
        hi += pad;
        if (hi - lo < 1) { hi = lo + 1; }
        var scale = (y1 - y0).toFloat() / (hi - lo);

        // In form space the zone edges are absolute TSB points,
        // ordered bottom-up: risk, optimal, grey, fresh, transition.
        var edges = [-30.0, -10.0, 5.0, 20.0] as Array<Float>;
        var fills = [FILLS[4], FILLS[3], FILLS[2], FILLS[1], FILLS[0]] as Array<Number>;
        dc.setPenWidth(3);
        for (var x = x0; x <= x1; x += 3) {
            var prevY = y1;
            for (var z = 0; z < 5; z++) {
                var bandTop = z < 4 ? edges[z] : hi;
                var yTop = y1 - ((bandTop - lo) * scale).toNumber();
                if (yTop < y0) { yTop = y0; }
                if (yTop < prevY) {
                    dc.setColor(fills[z], Graphics.COLOR_TRANSPARENT);
                    dc.drawLine(x, prevY, x, yTop);
                    prevY = yTop;
                }
            }
        }

        drawMiniLine(dc, form, lo, scale, x0, x1, y0, y1, Graphics.COLOR_WHITE, 3);
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

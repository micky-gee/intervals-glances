import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// High-resolution chart rendering for the 454x454 16-bit display.
module IntervalsCharts {

    // Form-zone band fills, dark enough that the series lines pop.
    // Zones are % of CTL, so in load-space each day's band edges are
    // multiples of that day's CTL (atl = ctl * (1 - form%/100)).
    const ZONE_MULS = [0.80, 0.95, 1.10, 1.30] as Array<Float>;
    const ZONE_FILLS = [
        0x3A3A57,   // transition (form > +20%): slate
        0x1D5380,   // fresh (+5..+20%): clear blue
        0x2E2E2E,   // grey zone (-10..+5%)
        0x1E7A45,   // optimal (-30..-10%): clear green
        0x5C1F26    // high risk (< -30%): deep red
    ] as Array<Number>;

    const CTL_COLOR = 0x4DA6FF;
    const ATL_COLOR = 0xCC66FF;

    // HRV-style metrics get a personal-baseline band (mean +/- SD over the
    // window) since absolute HRV norms are individual.
    function hasBaseline(key as String) as Boolean {
        return key.equals("hrv") || key.equals("hrvSDNN");
    }

    // [mean, sd, count] over the non-null values.
    function stats(values as Array) as Array {
        var n = values.size();
        var sum = 0.0;
        var count = 0;
        for (var i = 0; i < n; i++) {
            if (values[i] != null) {
                sum += values[i].toFloat();
                count++;
            }
        }
        if (count < 1) {
            return [0.0, 0.0, 0];
        }
        var mean = sum / count;
        var sq = 0.0;
        for (var i = 0; i < n; i++) {
            if (values[i] != null) {
                var d = values[i].toFloat() - mean;
                sq += d * d;
            }
        }
        return [mean, Math.sqrt(sq / count), count];
    }

    // Color for a value relative to its baseline band: above is good
    // (HRV-style metrics), in-band is neutral, low / very low warn.
    function baselineColor(v as Float, mean as Float, sd as Float,
            neutral as Number) as Number {
        if (v > mean + 0.75 * sd) { return 0x4DE68C; }   // above: green
        if (v < mean - 1.5 * sd) { return 0xFF5C5C; }    // very low: red
        if (v < mean - 0.75 * sd) { return 0xFFC44D; }   // low: amber
        return neutral;
    }

    // Chart metric metadata: key -> [label, decimals, line color].
    function defFor(key as String) as Array {
        if (key.equals("hrv")) { return ["HRV (rMSSD)", 0, 0x00E6CC]; }
        if (key.equals("hrvSDNN")) { return ["HRV SDNN", 0, 0x00B3A6]; }
        if (key.equals("restingHR")) { return ["RESTING HR", 0, 0xFF6666]; }
        if (key.equals("avgSleepingHR")) { return ["SLEEPING HR", 0, 0xFF9999]; }
        if (key.equals("rampRate")) { return ["RAMP RATE", 1, 0xFFA64D]; }
        if (key.equals("eftp")) { return ["eFTP", 0, 0xFFE14D]; }
        if (key.equals("weight")) { return ["WEIGHT", 1, 0xFFCC66]; }
        if (key.equals("bodyFat")) { return ["BODY FAT", 1, 0xFFB347]; }
        if (key.equals("vo2max")) { return ["VO2MAX", 1, 0x66FF99]; }
        if (key.equals("sleepScore")) { return ["SLEEP SCORE", 0, 0x9999FF]; }
        if (key.equals("sleepHours")) { return ["SLEEP HOURS", 1, 0x7FB2FF]; }
        if (key.equals("readiness")) { return ["READINESS", 0, 0x66FFCC]; }
        if (key.equals("steps")) { return ["STEPS", 0, 0xCCFF66]; }
        if (key.equals("spO2")) { return ["SPO2", 0, 0xFF80AA]; }
        if (key.equals("respiration")) { return ["RESPIRATION", 1, 0x80D4FF]; }
        if (key.equals("baevskySI")) { return ["STRESS INDEX", 1, 0xFF8066]; }
        if (key.equals("kcalConsumed")) { return ["CALORIES", 0, 0xFFD24D]; }
        return [key.toUpper(), 1, Graphics.COLOR_WHITE];
    }

    // CTL/ATL over the form-zone bands. The bands are computed per pixel
    // column from linearly interpolated CTL, so they follow fitness as it
    // changes through time.
    function drawLoadChart(dc as Dc, ctl as Array, atl as Array,
            x0 as Number, x1 as Number, y0 as Number, y1 as Number) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        var n = ctl.size();
        var range = loadRange(ctl, atl);
        var lo = range[0] as Float;
        var hi = range[1] as Float;
        var scale = (y1 - y0).toFloat() / (hi - lo);

        // Band underlay, one vertical strip per pixel column.
        dc.setPenWidth(1);
        for (var x = x0; x <= x1; x++) {
            var t = (x - x0).toFloat() / (x1 - x0) * (n - 1);
            var i = t.toNumber();
            var i2 = i + 1 < n ? i + 1 : i;
            var fr = t - i;
            var c = ctl[i].toFloat() * (1 - fr) + ctl[i2].toFloat() * fr;

            var prevY = y1;
            for (var z = 0; z < 5; z++) {
                var bandTop = z < 4 ? c * ZONE_MULS[z] : hi;
                var yTop = y1 - ((bandTop - lo) * scale).toNumber();
                if (yTop < y0) { yTop = y0; }
                if (yTop < prevY) {
                    dc.setColor(ZONE_FILLS[z], Graphics.COLOR_TRANSPARENT);
                    dc.drawLine(x, prevY, x, yTop);
                    prevY = yTop;
                }
            }
        }

        // Labeled gridlines at round numbers.
        var step = niceStep(hi - lo);
        var gv = ((lo / step).toNumber() + 1) * step;
        while (gv < hi) {
            var gy = y1 - ((gv - lo) * scale).toNumber();
            dc.setColor(0x4D4D4D, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x0, gy, x1, gy);
            dc.setColor(0x808080, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x0 - 6, gy, IntervalsUi.font(15), gv.format("%d"),
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            gv += step;
        }

        drawPolyline(dc, atl, lo, hi, x0, x1, y0, y1, ATL_COLOR, 3);
        drawPolyline(dc, ctl, lo, hi, x0, x1, y0, y1, CTL_COLOR, 4);
    }

    // Auto-scaled single-metric chart. Returns false when the series has
    // no plottable points. Nulls are skipped; sparse data gets point dots.
    function drawSeriesChart(dc as Dc, values as Array, color as Number,
            x0 as Number, x1 as Number, y0 as Number, y1 as Number,
            baseline as Boolean) as Boolean {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        var n = values.size();
        var minV = null;
        var maxV = null;
        var count = 0;
        for (var i = 0; i < n; i++) {
            var v = values[i];
            if (v != null) {
                var f = v.toFloat();
                if (minV == null || f < minV) { minV = f; }
                if (maxV == null || f > maxV) { maxV = f; }
                count++;
            }
        }
        if (count < 1) {
            return false;
        }
        var pad = (maxV - minV) * 0.12;
        if (pad <= 0) {
            pad = maxV != 0.0 ? maxV.abs() * 0.05 : 1.0;
        }
        minV -= pad;
        maxV += pad;

        // Personal baseline band (mean +/- 0.75 SD), under everything else.
        var mean = 0.0;
        var sd = 0.0;
        var useBase = false;
        if (baseline) {
            var st = stats(values);
            mean = st[0] as Float;
            sd = st[1] as Float;
            useBase = (st[2] as Number) >= 5 && sd > 0;
        }
        if (useBase) {
            var yHi = yAt(mean + 0.75 * sd, minV, maxV, y0, y1);
            var yLo = yAt(mean - 0.75 * sd, minV, maxV, y0, y1);
            dc.setColor(0x1F4030, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x0, yHi, x1 - x0, yLo - yHi);
        }

        // Faint gridlines with value labels on the new high-res canvas.
        dc.setPenWidth(1);
        for (var g = 0; g <= 2; g++) {
            var gy = y1 - (y1 - y0) * g / 2;
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x0, gy, x1, gy);
            var gv = minV + (maxV - minV) * g / 2;
            dc.setColor(0x808080, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x0 - 6, gy, Graphics.FONT_XTINY, gv.format("%.0f"),
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        drawPolyline(dc, values, minV, maxV, x0, x1, y0, y1, color, 3);

        // Point markers when the data is sparse (e.g. weigh-ins).
        if (count * 3 < n) {
            for (var i = 0; i < n; i++) {
                if (values[i] != null) {
                    var f = values[i].toFloat();
                    dc.setColor(useBase ? baselineColor(f, mean, sd, color) : color,
                        Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(xAt(i, n, x0, x1),
                        yAt(f, minV, maxV, y0, y1), 4);
                }
            }
        }

        // Emphasize the most recent point.
        for (var i = n - 1; i >= 0; i--) {
            if (values[i] != null) {
                dc.setColor(color, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(xAt(i, n, x0, x1),
                    yAt(values[i].toFloat(), minV, maxV, y0, y1), 5);
                break;
            }
        }
        return true;
    }

    // Polar load chart: the rectangular load chart bent around the bezel.
    // Time sweeps from lower-left (oldest) over 12 o'clock to lower-right
    // (newest); radius encodes load. The form-zone bands are drawn as radial
    // segments per angle step (scaled by interpolated CTL), with the ATL and
    // CTL polar polylines on top.
    // Display range for the load charts: tight around the data and the
    // form-zone band envelope so the chart fills its space. Returns [lo, hi].
    function loadRange(ctl as Array, atl as Array) as Array {
        var n = ctl.size();
        var ctlMin = ctl[0].toFloat();
        var ctlMax = ctlMin;
        var dataMin = ctlMin;
        var dataMax = ctlMin;
        for (var i = 0; i < n; i++) {
            var c = ctl[i].toFloat();
            var a = atl[i].toFloat();
            if (c < ctlMin) { ctlMin = c; }
            if (c > ctlMax) { ctlMax = c; }
            if (c < dataMin) { dataMin = c; }
            if (a < dataMin) { dataMin = a; }
            if (c > dataMax) { dataMax = c; }
            if (a > dataMax) { dataMax = a; }
        }
        // Always include the fresh edge below and the whole optimal band
        // (plus a strip of high-risk) above.
        var lo = dataMin < ctlMin * 0.78 ? dataMin : ctlMin * 0.78;
        var hi = dataMax > ctlMax * 1.38 ? dataMax : ctlMax * 1.38;
        var pad = (hi - lo) * 0.03;
        lo -= pad;
        hi += pad;
        if (lo < 0) { lo = 0.0; }
        if (hi - lo < 1) { hi = lo + 1; }
        return [lo, hi];
    }

    // A readable grid step giving at most ~5 lines across the span.
    function niceStep(span as Float) as Number {
        var cands = [2, 5, 10, 20, 25, 50, 100] as Array<Number>;
        for (var i = 0; i < cands.size(); i++) {
            if (span / cands[i] <= 5.5) {
                return cands[i];
            }
        }
        return 200;
    }

    function drawPolarLoadChart(dc as Dc, ctl as Array, atl as Array,
            cx as Number, cy as Number, rIn as Number, rOut as Number) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        var n = ctl.size();
        var range = loadRange(ctl, atl);
        var lo = range[0] as Float;
        var hi = range[1] as Float;
        var scale = (rOut - rIn) / (hi - lo);

        // Band underlay: one spoke per angle step, wide enough to overlap.
        var steps = 240;
        dc.setPenWidth(5);
        for (var s = 0; s <= steps; s++) {
            var t = s.toFloat() / steps * (n - 1);
            var i = t.toNumber();
            var i2 = i + 1 < n ? i + 1 : i;
            var fr = t - i;
            var c = ctl[i].toFloat() * (1 - fr) + ctl[i2].toFloat() * fr;

            var rad = (RING_START_DEG - RING_SWEEP_DEG * s / steps)
                * Math.PI / 180.0;
            var cosv = Math.cos(rad);
            var sinv = Math.sin(rad);

            var prevR = rIn;
            for (var z = 0; z < 5; z++) {
                var bandTop = z < 4 ? c * ZONE_MULS[z] : hi;
                var r2 = rIn + ((bandTop - lo) * scale).toNumber();
                if (r2 > rOut) { r2 = rOut; }
                if (r2 > prevR) {
                    dc.setColor(ZONE_FILLS[z], Graphics.COLOR_TRANSPARENT);
                    dc.drawLine(cx + (prevR * cosv).toNumber(), cy - (prevR * sinv).toNumber(),
                        cx + (r2 * cosv).toNumber(), cy - (r2 * sinv).toNumber());
                    prevR = r2;
                }
            }
        }

        // Faint radial time spokes every 30 days back from today.
        dc.setPenWidth(1);
        dc.setColor(0x4D4D4D, Graphics.COLOR_TRANSPARENT);
        for (var k = 1; n - 1 - k * 30 > 0; k++) {
            var rad = (RING_START_DEG
                - RING_SWEEP_DEG * (n - 1 - k * 30) / (n - 1)) * Math.PI / 180.0;
            var cosv = Math.cos(rad);
            var sinv = Math.sin(rad);
            dc.drawLine(cx + (rIn * cosv).toNumber(), cy - (rIn * sinv).toNumber(),
                cx + (rOut * cosv).toNumber(), cy - (rOut * sinv).toNumber());
        }

        // Labeled value arcs at round numbers, labels in the bottom gap.
        var step = niceStep(hi - lo);
        var gv = ((lo / step).toNumber() + 1) * step;
        while (gv < hi) {
            var r = rIn + ((gv - lo) * scale).toNumber();
            dc.setColor(0x4D4D4D, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, r, Graphics.ARC_COUNTER_CLOCKWISE, -60, 240);
            var ly = cy + r;
            if (ly < cy * 2 - 28) {
                dc.setColor(0x808080, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, ly, IntervalsUi.font(15), gv.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
            gv += step;
        }

        drawPolarSeries(dc, atl, lo, hi, cx, cy, rIn, rOut, ATL_COLOR, 3);
        drawPolarSeries(dc, ctl, lo, hi, cx, cy, rIn, rOut, CTL_COLOR, 4);
    }

    function drawPolarSeries(dc as Dc, series as Array, lo as Float, hi as Float,
            cx as Number, cy as Number, rIn as Number, rOut as Number,
            color as Number, pen as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pen);
        var n = series.size();
        var scale = (rOut - rIn) / (hi - lo);
        var px = -1;
        var py = -1;
        for (var i = 0; i < n; i++) {
            var rad = (RING_START_DEG - RING_SWEEP_DEG * i / (n - 1))
                * Math.PI / 180.0;
            var r = rIn + ((series[i].toFloat() - lo) * scale).toNumber();
            if (r > rOut) { r = rOut; }
            if (r < rIn) { r = rIn; }
            var x = cx + (r * Math.cos(rad)).toNumber();
            var y = cy - (r * Math.sin(rad)).toNumber();
            if (px >= 0) {
                dc.drawLine(px, py, x, y);
            }
            px = x;
            py = y;
        }
        dc.setPenWidth(1);
    }

    // Radial ring chart: the time window wraps around the bezel. One radial
    // bar per day from lower-left (oldest), over 12 o'clock, to lower-right
    // (newest), leaving a 60 degree gap at the bottom. Bar length encodes
    // the value within the window's min..max; the newest bar is white.
    const RING_START_DEG = 240.0;
    const RING_SWEEP_DEG = 300.0;

    function drawRingChart(dc as Dc, values as Array, color as Number,
            cx as Number, cy as Number, rIn as Number, rOut as Number,
            baseline as Boolean) as Boolean {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        var n = values.size();
        var minV = null;
        var maxV = null;
        var count = 0;
        var lastIdx = -1;
        for (var i = 0; i < n; i++) {
            var v = values[i];
            if (v != null) {
                var f = v.toFloat();
                if (minV == null || f < minV) { minV = f; }
                if (maxV == null || f > maxV) { maxV = f; }
                count++;
                lastIdx = i;
            }
        }
        if (count < 1 || n < 2) {
            return false;
        }
        if (maxV - minV <= 0) {
            maxV = minV + (minV.abs() * 0.05 + 1.0);
        }

        var r1 = rIn + 4;
        var span = rOut - rIn - 8;

        // Personal baseline band (mean +/- 0.75 SD), drawn under the bars.
        var mean = 0.0;
        var sd = 0.0;
        var useBase = false;
        if (baseline) {
            var st = stats(values);
            mean = st[0] as Float;
            sd = st[1] as Float;
            useBase = (st[2] as Number) >= 5 && sd > 0;
        }
        if (useBase) {
            dc.setPenWidth(1);
            dc.setColor(0x1F4030, Graphics.COLOR_TRANSPARENT);
            var bLo = bandR(mean - 0.75 * sd, minV, maxV, r1, span);
            var bHi = bandR(mean + 0.75 * sd, minV, maxV, r1, span);
            for (var r = bLo; r <= bHi; r++) {
                dc.drawArc(cx, cy, r, Graphics.ARC_COUNTER_CLOCKWISE, -60, 240);
            }
        }

        // Concentric grid arcs across the sweep.
        dc.setPenWidth(1);
        dc.setColor(0x262626, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, rIn, Graphics.ARC_COUNTER_CLOCKWISE, -60, 240);
        dc.drawArc(cx, cy, (rIn + rOut) / 2, Graphics.ARC_COUNTER_CLOCKWISE, -60, 240);
        dc.setColor(0x3D3D3D, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, rOut, Graphics.ARC_COUNTER_CLOCKWISE, -60, 240);

        // Bar width follows the per-day arc spacing on the mid radius.
        var penW = (2.0 * Math.PI * ((rIn + rOut) / 2)
            * (RING_SWEEP_DEG / 360.0) / n * 0.65).toNumber();
        if (penW < 2) { penW = 2; }
        if (penW > 9) { penW = 9; }
        dc.setPenWidth(penW);

        for (var i = 0; i < n; i++) {
            var v = values[i];
            if (v == null) {
                continue;
            }
            var f = v.toFloat();
            var frac = (f - minV) / (maxV - minV);
            if (frac < 0.05) { frac = 0.05; }   // always a visible nub
            var rad = (RING_START_DEG - RING_SWEEP_DEG * i / (n - 1))
                * Math.PI / 180.0;
            var cosv = Math.cos(rad);
            var sinv = Math.sin(rad);
            var r2 = r1 + span * frac;
            var barColor = useBase ? baselineColor(f, mean, sd, color) : color;
            dc.setColor(i == lastIdx ? Graphics.COLOR_WHITE : barColor,
                Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cx + (r1 * cosv).toNumber(), cy - (r1 * sinv).toNumber(),
                cx + (r2 * cosv).toNumber(), cy - (r2 * sinv).toNumber());
        }
        dc.setPenWidth(1);
        return true;
    }

    function bandR(v as Float, minV as Float, maxV as Float,
            r1 as Number, span as Number) as Number {
        var frac = (v - minV) / (maxV - minV);
        if (frac < 0.0) { frac = 0.0; }
        if (frac > 1.0) { frac = 1.0; }
        return r1 + (span * frac).toNumber();
    }

    function xAt(i as Number, n as Number, x0 as Number, x1 as Number) as Number {
        return x0 + (x1 - x0) * i / (n - 1);
    }

    function yAt(v as Float, minV as Float, maxV as Float,
            y0 as Number, y1 as Number) as Number {
        var y = y1 - (((v - minV) / (maxV - minV)) * (y1 - y0)).toNumber();
        if (y < y0) { y = y0; }
        if (y > y1) { y = y1; }
        return y;
    }

    // Connect consecutive non-null points, scaled to minV..maxV.
    function drawPolyline(dc as Dc, values as Array, minV as Float,
            maxV as Float, x0 as Number, x1 as Number,
            y0 as Number, y1 as Number, color as Number, pen as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pen);
        var n = values.size();
        var px = -1;
        var py = -1;
        for (var i = 0; i < n; i++) {
            var v = values[i];
            if (v == null) {
                continue;
            }
            var x = xAt(i, n, x0, x1);
            var y = yAt(v.toFloat(), minV, maxV, y0, y1);
            if (px >= 0) {
                dc.drawLine(px, py, x, y);
            }
            px = x;
            py = y;
        }
        dc.setPenWidth(1);
    }
}

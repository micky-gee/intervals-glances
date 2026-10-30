import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

// Text and table rendering for the full-screen pages: scalable vector fonts
// auto-fitted to their space, sparkline tables and label/value lists.
module IntervalsUi {

    const FACES = ["RobotoCondensedBold", "RobotoRegular", "RobotoCondensedRegular"];

    // Cohesive accent palette for the 16-bit AMOLED/MicroLED panel.
    const CORAL = 0xFF5C5C;
    const TEAL = 0x00E6CC;
    const VIOLET = 0xB388FF;
    const BLUE = 0x4DA6FF;
    const AMBER = 0xFFC44D;
    const MINT = 0x6BE8A0;
    const PINK = 0xFF80AA;
    const LIME = 0xCCFF66;
    const SLATE = 0x8C8C99;
    const DIM = 0x8C8C99;

    var _cache as Dictionary = {};
    var _vectorOk as Boolean = true;
    var _warned as Boolean = false;

    // Vector font at an exact pixel size, falling back to the closest
    // bitmap font if the device rejects every face.
    function font(size as Number) {
        if (_vectorOk && Graphics has :getVectorFont) {
            var f = _cache[size];
            if (f == null) {
                f = Graphics.getVectorFont({ :face => FACES, :size => size });
                if (f != null) {
                    _cache[size] = f;
                }
            }
            if (f != null) {
                return f;
            }
            _vectorOk = false;
            if (!_warned) {
                _warned = true;
                System.println("vector fonts unavailable, using bitmap fallback");
            }
        }
        if (size >= 80) { return Graphics.FONT_NUMBER_HOT; }
        if (size >= 48) { return Graphics.FONT_LARGE; }
        if (size >= 36) { return Graphics.FONT_MEDIUM; }
        if (size >= 28) { return Graphics.FONT_SMALL; }
        if (size >= 22) { return Graphics.FONT_TINY; }
        return Graphics.FONT_XTINY;
    }

    // Largest size <= start whose rendered width fits maxW.
    function fitSize(dc as Dc, text as String, maxW as Number, start as Number) as Number {
        var s = start;
        while (s > 10 && dc.getTextWidthInPixels(text, font(s)) > maxW) {
            s -= 2;
        }
        return s;
    }

    function drawFit(dc as Dc, x as Number, y as Number, text as String,
            maxW as Number, start as Number, color as Number, just as Number) as Void {
        var s = fitSize(dc, text, maxW, start);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font(s), text, just);
    }

    // Text sizes as thousandths of screen width, calibrated on the 454px
    // fenix 8 Pro. TXT_MIN is the floor for any text a page draws: below about
    // 28px there, small caps stop being readable at a glance.
    const TXT_HEAD = 75;
    const TXT_LABEL = 70;
    const TXT_MIN = 62;

    function px(dc as Dc, permille as Number) as Number {
        return dc.getWidth() * permille / 1000;
    }

    const MAX_ROWS = 4;

    // Severity colours for the subjective 1 (best) .. 4 (worst) scales.
    const SEVERITY = [0x6BE8A0, 0x4DA6FF, 0xFFC44D, 0xFF5C5C] as Array<Number>;

    function severityColor(v) as Number {
        var i = v == null ? -1 : v.toNumber() - 1;
        return i >= 0 && i <= 3 ? SEVERITY[i] : Graphics.COLOR_WHITE;
    }

    // A sparkline table: one row per metric, after Tufte. Each row reads
    // left to right as name, recent history, current value:
    //
    //   REST HR bpm
    //   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*      45
    //
    // The columns are shared, so every sparkline spans the same days at the
    // same x and a bad night lines up with the HRV dip in the row below.
    // Labels share one size and values another, so the rows read as a table.
    // row = [label, unit, value, accent, valueColor, series?, ordinal, range]
    function drawTable(dc as Dc, rows as Array, top as Number, bottom as Number) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var n = rows.size();
        if (n == 0) {
            return;
        }
        if (n == 1) {
            drawHero(dc, rows[0] as Array, top, bottom);
            return;
        }
        // Fewer rows get taller ones, up to a point; the block stays centred
        // in the space it was given.
        var rowH = (bottom - top) / n;
        var cap = h * (n == 2 ? 30 : 24) / 100;
        if (rowH > cap) {
            rowH = cap;
        }
        var y0 = top + ((bottom - top) - rowH * n) / 2;
        var y1 = y0 + rowH * n;

        // The table is inscribed in the round screen: as wide as the chord
        // at its narrowest content line, near the first or last row edge.
        var inset = rowH / 8;
        var half = chordHalf(w, h, y0 + inset);
        var halfB = chordHalf(w, h, y1 - inset);
        if (halfB < half) {
            half = halfB;
        }
        var pad = w * 3 / 100;
        var left = w / 2 - half + pad;
        var right = w / 2 + half - pad;
        var valW = (right - left) * 40 / 100;
        var gap = w * 3 / 100;
        var sparkR = right - valW - gap;

        // One value size: the largest at which every value fits its column.
        var vs = clampSize(rowH * 80 / 100, w * 9 / 100, w * 20 / 100);
        for (var r = 0; r < n; r++) {
            vs = fitSize(dc, (rows[r] as Array)[2] as String, valW, vs);
        }
        // One label size: the largest at which every label clears its value.
        // A unit that would push the labels below the floor is dropped.
        var vf = font(vs);
        var floor = px(dc, TXT_MIN);
        var ls = clampSize(rowH * 40 / 100, floor, px(dc, 95));
        var room = new Array<Number>[n];
        for (var r = 0; r < n; r++) {
            var row = rows[r] as Array;
            room[r] = right - left - dc.getTextWidthInPixels(row[2] as String, vf) - gap;
            var s = fitSize(dc, labelText(row, true), room[r], ls);
            if (s < floor) {
                s = fitSize(dc, labelText(row, false), room[r], ls);
            }
            if (s < ls) {
                ls = s < floor ? floor : s;
            }
        }
        var lf = font(ls);

        for (var r = 0; r < n; r++) {
            var row = rows[r] as Array;
            var rt = y0 + rowH * r;
            var withUnit = dc.getTextWidthInPixels(labelText(row, true), lf) <= room[r];
            drawRowLabel(dc, left, rt + rowH * 24 / 100, row[0] as String,
                withUnit ? row[1] as String : "", lf, row[3] as Number);
            var series = row[5] as Array?;
            if (series != null) {
                var sy0 = rt + rowH * 50 / 100;
                var sy1 = rt + rowH * 88 / 100;
                if (row[6] as Boolean) {
                    drawStrip(dc, left, sparkR, sy0, sy1, series);
                } else {
                    drawSpark(dc, left, sparkR, sy0, sy1, series, row[3] as Number);
                }
            }
            dc.setColor(row[4] as Number, Graphics.COLOR_TRANSPARENT);
            dc.drawText(right, rt + rowH / 2, vf, row[2] as String,
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function labelText(row as Array, withUnit as Boolean) as String {
        var unit = row[1] as String;
        return withUnit && unit.length() > 0 ? (row[0] as String) + " " + unit : row[0] as String;
    }

    // A page with a single metric gets it large, set like the ring pages:
    // name, value, then its history across the screen and the window's range.
    function drawHero(dc as Dc, row as Array, top as Number, bottom as Number) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var span = bottom - top;
        var just = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        // A line needs a few readings that differ; a flat or two-point one
        // says less than the value above it. Without one, name and value sit
        // together in the middle instead of around a hole.
        var series = row[5] as Array?;
        var range = row[7] as String;
        if (series != null && (points(series) < 3
                || !(row[6] as Boolean) && range.length() == 0)) {
            series = null;
        }
        var ly = top + span * 10 / 100;
        var vy = top + span * 36 / 100;
        if (series == null && range.length() == 0) {
            ly = top + span / 2 - h * 16 / 100;
            vy = top + span / 2 + h * 3 / 100;
        }

        var lf = font(fitSize(dc, labelText(row, true), chordHalf(w, h, ly) * 17 / 10, px(dc, 95)));
        var unit = row[1] as String;
        var lw = dc.getTextWidthInPixels(labelText(row, true), lf);
        drawRowLabel(dc, cx - lw / 2, ly, row[0] as String, unit, lf, row[3] as Number);

        drawFit(dc, cx, vy, row[2] as String, w * 60 / 100,
            w * 26 / 100, row[4] as Number, just);

        var sy0 = top + span * 60 / 100;
        var sy1 = top + span * 82 / 100;
        var half = chordHalf(w, h, sy1) - w * 4 / 100;
        if (series != null) {
            if (row[6] as Boolean) {
                drawStrip(dc, cx - half, cx + half, sy0, sy1, series);
            } else {
                drawSpark(dc, cx - half, cx + half, sy0, sy1, series, row[3] as Number);
            }
        }
        if (range.length() > 0) {
            drawFit(dc, cx, top + span * 94 / 100, range, w * 50 / 100,
                px(dc, TXT_HEAD), DIM, just);
        }
    }

    function points(a as Array) as Number {
        var c = 0;
        for (var i = 0; i < a.size(); i++) {
            if (a[i] != null) {
                c++;
            }
        }
        return c;
    }

    // Label in its accent colour, unit after it in grey.
    function drawRowLabel(dc as Dc, x as Number, y as Number, label as String,
            unit as String, f, color as Number) as Void {
        var just = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, f, label, just);
        if (unit.length() > 0) {
            dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + dc.getTextWidthInPixels(label + " ", f), y, f, unit, just);
        }
    }

    // Word-sized line chart: the series in grey over its normal range
    // (mean +/- 1 SD, once there are enough points to have one), the latest
    // reading marked in the row's accent. Nulls are skipped, joining the
    // readings either side, so sparse data such as weigh-ins still reads.
    function drawSpark(dc as Dc, x0 as Number, x1 as Number, y0 as Number,
            y1 as Number, values as Array, accent as Number) as Void {
        var n = values.size();
        var count = 0;
        var sum = 0.0;
        var sumSq = 0.0;
        var lo = null;
        var hi = null;
        for (var i = 0; i < n; i++) {
            if (values[i] != null) {
                var f = values[i].toFloat();
                count++;
                sum += f;
                sumSq += f * f;
                if (lo == null || f < lo) { lo = f; }
                if (hi == null || f > hi) { hi = f; }
            }
        }
        if (count == 0) {
            return;
        }
        var mean = sum / count;
        var v = sumSq / count - mean * mean;
        var sd = v > 0 ? Math.sqrt(v).toFloat() : 0.0;
        var band = count >= 5 && sd > 0;
        if (band) {
            if (mean - sd < lo) { lo = mean - sd; }
            if (mean + sd > hi) { hi = mean + sd; }
        }
        if (hi - lo < 0.001) {
            lo -= 1.0;
            hi += 1.0;
        }
        var scale = (y1 - y0).toFloat() / (hi - lo);

        if (band) {
            var bt = y1 - ((mean + sd - lo) * scale).toNumber();
            var bb = y1 - ((mean - sd - lo) * scale).toNumber();
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x0, bt, x1 - x0, bb - bt + 1);
        }

        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        var w = dc.getWidth();
        dc.setPenWidth(w >= 360 ? 3 : 2);
        dc.setColor(0xB3B3B3, Graphics.COLOR_TRANSPARENT);
        var px = -1;            // no point drawn yet
        var py = 0;
        for (var i = 0; i < n; i++) {
            if (values[i] != null) {
                var x = n > 1 ? x0 + (x1 - x0) * i / (n - 1) : x1;
                var y = y1 - ((values[i].toFloat() - lo) * scale).toNumber();
                if (px >= 0) {
                    dc.drawLine(px, py, x, y);
                }
                px = x;
                py = y;
            }
        }
        dc.setPenWidth(1);
        if (px >= 0) {
            dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, py, w / 80 > 3 ? w / 80 : 3);
        }
    }

    // The ordinal counterpart for 1..4 scales: one bar per day, taller and
    // warmer the worse the day, a faint baseline tick where none was logged.
    // Bars sit on the same day positions as the sparklines above them.
    function drawStrip(dc as Dc, x0 as Number, x1 as Number, y0 as Number,
            y1 as Number, values as Array) as Void {
        var n = values.size();
        if (n < 2) {
            return;
        }
        var bw = (x1 - x0) * 6 / (10 * (n - 1));
        if (bw < 2) { bw = 2; }
        for (var i = 0; i < n; i++) {
            var x = x0 + (x1 - x0) * i / (n - 1) - bw / 2;
            var v = values[i];
            var lvl = v == null ? 0 : v.toNumber();
            if (lvl >= 1 && lvl <= 4) {
                var bh = (y1 - y0) * lvl / 4;
                dc.setColor(SEVERITY[lvl - 1], Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, y1 - bh, bw, bh);
            } else {
                dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, y1 - 2, bw, 2);
            }
        }
    }

    // Plain label / value list for text-only pages (status): label left in
    // grey, value right, in a table inscribed in the round screen.
    // item = [label, value, valueColor]
    function drawPairs(dc as Dc, items as Array, top as Number, bottom as Number) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var n = items.size();
        if (n == 0) {
            return;
        }
        var rowH = (bottom - top) / n;
        if (rowH > h * 14 / 100) {
            rowH = h * 14 / 100;
        }
        var y0 = top + ((bottom - top) - rowH * n) / 2;
        var y1 = y0 + rowH * n;
        var half = chordHalf(w, h, y0 + rowH / 4);
        var halfB = chordHalf(w, h, y1 - rowH / 4);
        if (halfB < half) {
            half = halfB;
        }
        var pad = w * 3 / 100;
        var left = w / 2 - half + pad;
        var right = w / 2 + half - pad;
        var ls = clampSize(rowH * 50 / 100, px(dc, TXT_MIN), px(dc, TXT_LABEL));
        var vs = clampSize(rowH * 68 / 100, px(dc, TXT_LABEL), w * 95 / 1000);
        var just = Graphics.TEXT_JUSTIFY_VCENTER;
        for (var i = 0; i < n; i++) {
            var it = items[i] as Array;
            var cy = y0 + rowH * i + rowH / 2;
            var label = it[0] as String;
            var lf = font(ls);
            dc.setColor(SLATE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(left, cy, lf, label, Graphics.TEXT_JUSTIFY_LEFT | just);
            var room = right - left - dc.getTextWidthInPixels(label, lf) - w * 4 / 100;
            drawFit(dc, right, cy, it[1] as String, room, vs, it[2] as Number,
                Graphics.TEXT_JUSTIFY_RIGHT | just);
        }
    }

    function clampSize(v as Number, lo as Number, hi as Number) as Number {
        if (v < lo) { return lo; }
        if (v > hi) { return hi; }
        return v;
    }

    // Half the chord a round screen offers at height y; square screens keep
    // the full width.
    function chordHalf(w as Number, h as Number, y as Number) as Number {
        if (w != h) {
            return w / 2;
        }
        var r = w / 2;
        var dy = (y - r).abs();
        if (dy >= r) {
            return 0;
        }
        return Math.sqrt(r * r - dy * dy).toNumber();
    }
}

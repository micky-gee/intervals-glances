import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

// Modern text rendering for the full-screen pages: scalable vector fonts
// auto-fitted to their space, value+unit pairs, and a stat-tile grid.
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

    // A value with a smaller, dimmer unit hugging its baseline, centered
    // as a group on cx.
    function drawValueUnit(dc as Dc, cx as Number, cy as Number,
            value as String, unit as String, maxW as Number, start as Number,
            color as Number) as Void {
        var hasUnit = unit.length() > 0;
        var s = fitSize(dc, value, hasUnit ? maxW * 3 / 4 : maxW, start);
        var f = font(s);
        var uMin = dc.getWidth() * 4 / 100;
        if (uMin < 12) { uMin = 12; }
        var us = s / 2 < uMin ? uMin : s / 2;
        var uf = font(us);
        var wv = dc.getTextWidthInPixels(value, f);
        var wu = hasUnit ? dc.getTextWidthInPixels(unit, uf) + 5 : 0;
        var x0 = cx - (wv + wu) / 2;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0, cy, f, value,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        if (hasUnit) {
            dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x0 + wv + 5, cy + s / 5, uf, unit,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // One stat tile: auto-fitted value (+unit) with a colored micro-label.
    // item = [label, value, unit, accent] or
    //        [label, value, unit, accent, valueColor]
    // Sizes are fractions of screen width so the same layout holds from
    // 218px MIP faces up to the 454px MicroLED (fractions calibrated to
    // reproduce the tuned 454px look exactly).
    // Tile contents are sized from the height of the row they sit in, not from
    // the screen alone: a two-row page then uses the space it has, and a
    // three-row page keeps a clear gap between rows instead of the four pixels
    // a fixed size left it with. Both are clamped so the extremes stay sane.
    function drawTile(dc as Dc, cx as Number, cy as Number, maxW as Number,
            rowH as Number, item as Array) as Void {
        var w = dc.getWidth();
        // The lower bounds are absolute, not a fraction of the screen: on the
        // smallest watches a proportional floor put the label under 10px.
        var vs = clampSize(rowH * 68 / 100, w * 10 / 100, w * 22 / 100);
        var ls = clampSize(rowH * 18 / 100, w * 42 / 1000, w * 55 / 1000);
        if (vs < 24) { vs = 24; }
        if (ls < 11) { ls = 11; }

        var valueColor = item.size() > 4
            ? item[4] as Number : Graphics.COLOR_WHITE;
        drawValueUnit(dc, cx, cy - rowH * 12 / 100, item[1] as String,
            item[2] as String, maxW, vs, valueColor);
        // Fitted rather than drawn flat, so a long label such as STRESS IDX
        // shrinks instead of running past the tile.
        drawFit(dc, cx, cy + rowH * 37 / 100, item[0] as String, maxW, ls,
            item[3] as Number,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function clampSize(v as Number, lo as Number, hi as Number) as Number {
        if (v < lo) { return lo; }
        if (v > hi) { return hi; }
        return v;
    }

    // Two-column grid of stat tiles, sized for the round 454px screen.
    // An odd final tile is centered on its own row.
    function drawTiles(dc as Dc, items as Array) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var n = items.size();
        if (n == 0) {
            return;
        }
        var rows = (n + 1) / 2;
        // Runs from just under the header to just above the page dots.
        var top = h * 16 / 100;
        var span = h * 74 / 100;
        var rowH = span / rows;
        for (var i = 0; i < n; i++) {
            var r = i / 2;
            var lastOdd = (n % 2 == 1) && (i == n - 1);
            var cy = top + rowH * r + rowH / 2;
            // How much width this row actually has. A row near the top or
            // bottom of a round screen sits on a shorter chord than one across
            // the middle, so a single fixed tile width either wastes the middle
            // or overhangs the ends. Measured at whichever edge of the row is
            // furthest from the centre, which is where the chord is shortest.
            var half = rowHalfWidth(w, h, cy, rowH);
            var usable = half * 2 - w * 8 / 100;
            var maxW = lastOdd ? usable : (usable - w * 4 / 100) / 2;
            var cx = w / 2;
            if (!lastOdd) {
                var off = (maxW + w * 4 / 100) / 2;
                cx = i % 2 == 0 ? w / 2 - off : w / 2 + off;
            }
            drawTile(dc, cx, cy, maxW, rowH, items[i] as Array);
        }
    }

    // Half the chord the screen offers at the widest-reaching edge of a row.
    // Square screens keep the full width.
    function rowHalfWidth(w as Number, h as Number, cy as Number,
            rowH as Number) as Number {
        if (w != h) {
            return w / 2;
        }
        var r = w / 2;
        var top = cy - rowH / 2;
        var bot = cy + rowH / 2;
        var dy = (r - top).abs() > (bot - r).abs() ? (r - top).abs() : (bot - r).abs();
        if (dy >= r) {
            return 0;
        }
        return Math.sqrt(r * r - dy * dy).toNumber();
    }
}

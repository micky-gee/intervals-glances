import Toybox.Graphics;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;

// One view class renders all pages; the page index selects the content.
class IntervalsWidgetView extends WatchUi.View {

    hidden var _page as Number;

    function initialize(page as Number) {
        View.initialize();
        _page = page;
    }

    function onShow() as Void {
        IntervalsRefresh.startIfStale();
    }

    function onUpdate(dc as Dc) as Void {
        IntervalsData.beginFrame();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var pages = IntervalsPages.list();
        var id = pages[_page < pages.size() ? _page : 0] as String;

        if (id.equals("migrate")) {
            drawMigratePage(dc);
        } else if (id.find("g:") == 0) {
            var round = id.substring(2, 3).equals("r");
            var type = id.substring(4, id.length());
            if (type.equals("load")) {
                drawLoadPage(dc, round);
            } else {
                drawMetricPage(dc, type, round);
            }
        } else if (id.find("d:") == 0) {
            drawDataPage(dc, id.substring(2, id.length()));
        } else {
            drawNonePage(dc);
        }

        if (IntervalsRefresh.zoomActive && IntervalsPages.isChart(id)) {
            drawZoomOverlay(dc);
        } else {
            drawPageDots(dc, pages.size());
        }
    }

    // Map a data-page type key to its page.
    hidden function drawDataPage(dc as Dc, type as String) as Void {
        if (type.equals("form")) {
            drawFormPage(dc);
        } else if (type.equals("recovery")) {
            drawSparkPage(dc, "RECOVERY", type);
        } else if (type.equals("sleep")) {
            drawSparkPage(dc, "SLEEP", type);
        } else if (type.equals("body")) {
            drawSparkPage(dc, "BODY", type);
        } else if (type.equals("fuel")) {
            drawSparkPage(dc, "FUEL + STEPS", type);
        } else if (type.equals("feel")) {
            drawSparkPage(dc, "HOW YOU FEEL", type);
        } else {
            drawStatusPage(dc);
        }
    }

    // The status page is the always-available entry point for OAuth linking
    // (reachable even when the migration nudge is snoozed), so it advertises
    // the action whenever the account isn't linked yet.
    hidden function drawLinkHint(dc as Dc) as Void {
        if (IntervalsSettings.oauthToken() != null) {
            return;
        }
        IntervalsUi.drawFit(dc, dc.getWidth() / 2, dc.getHeight() * 89 / 100,
            IntervalsAuth.busy() ? "Open Garmin Connect on phone"
                : "Press START to link OAuth",
            dc.getWidth() * 70 / 100, IntervalsUi.px(dc, IntervalsUi.TXT_MIN), IntervalsUi.MINT,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Nudge for API-key users to link their account via OAuth. Paging away
    // snoozes it for MIGRATION_SNOOZE_DAYS (handled in the delegate).
    hidden function drawMigratePage(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        drawHeader(dc, "INTERVALS.ICU");

        IntervalsUi.drawFit(dc, cx, h * 34 / 100, "New: link your",
            w * 64 / 100, w * 8 / 100, Graphics.COLOR_WHITE,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        IntervalsUi.drawFit(dc, cx, h * 43 / 100, "account by OAuth -",
            w * 64 / 100, w * 8 / 100, Graphics.COLOR_WHITE,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        IntervalsUi.drawFit(dc, cx, h * 52 / 100, "no more API key",
            w * 64 / 100, w * 8 / 100, Graphics.COLOR_WHITE,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (IntervalsAuth.busy()) {
            IntervalsUi.drawFit(dc, cx, h * 70 / 100, "Open Garmin Connect",
                w * 62 / 100, IntervalsUi.px(dc, IntervalsUi.TXT_HEAD), IntervalsUi.MINT,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            IntervalsUi.drawFit(dc, cx, h * 78 / 100, "on your phone",
                w * 62 / 100, IntervalsUi.px(dc, IntervalsUi.TXT_HEAD), IntervalsUi.MINT,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        IntervalsUi.drawFit(dc, cx, h * 68 / 100, "START  connect",
            w * 56 / 100, IntervalsUi.px(dc, IntervalsUi.TXT_HEAD), IntervalsUi.MINT,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        IntervalsUi.drawFit(dc, cx, h * 76 / 100, "DOWN  later",
            w * 56 / 100, IntervalsUi.px(dc, IntervalsUi.TXT_HEAD), IntervalsUi.DIM,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Shown only when every page is set to "off".
    hidden function drawNonePage(dc as Dc) as Void {
        drawHeader(dc, "INTERVALS");
        drawMessage(dc, "Enable graph or data\npages in settings");
    }

    // START opens this on chart pages: bold white +/- glyphs sitting next to
    // the physical UP and DOWN buttons (which adjust the window). UP/+ zooms
    // in (fewer days), DOWN/- zooms out (more days); the chart behind rescales
    // live and the day count rides in the header / ring centre. Button
    // heights are from the fenix 8 key map (UP ~50%, DOWN ~83% of the screen).
    hidden function drawZoomOverlay(dc as Dc) as Void {
        var days = IntervalsData.zoomDays();
        drawZoomGlyph(dc, dc.getHeight() * 50 / 100, true,
            days <= IntervalsData.MIN_ZOOM);
        drawZoomGlyph(dc, dc.getHeight() * 83 / 100, false,
            days >= IntervalsData.MAX_ZOOM);
    }

    // One +/- glyph as bold rounded bars, tucked just inside the round screen
    // edge at the given height so it hugs its button without clipping.
    hidden function drawZoomGlyph(dc as Dc, cy as Number, isPlus as Boolean,
            dim as Boolean) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var half = w * 5 / 100;
        var thick = w * 22 / 1000;
        // Left edge of the (round) screen at this height, so the glyph never
        // lands in the bezel where the display curves in.
        var rr = w / 2;
        var dy = cy - h / 2;
        var inside = rr * rr - dy * dy;
        var edge = inside > 0 ? (rr - Math.sqrt(inside)).toNumber() : 0;
        var cx = edge + half + w * 3 / 100;

        dc.setColor(dim ? IntervalsUi.DIM : Graphics.COLOR_WHITE,
            Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - half, cy - thick / 2, 2 * half, thick, thick / 2);
        if (isPlus) {
            dc.fillRoundedRectangle(cx - thick / 2, cy - half, thick, 2 * half, thick / 2);
        }
    }

    // Header label with the transient states layered on top.
    hidden function busyLabel(title as String) as String {
        if (IntervalsAuth.busy()) {
            return "CONNECTING...";
        }
        if (IntervalsRefresh.isBusy()) {
            return "SYNCING...";
        }
        return title;
    }

    // Label what is actually plotted: the zoom can reach past the history
    // cached so far, which is then being backfilled.
    hidden function windowLabel() as String {
        var days = IntervalsData.zoomDays();
        var have = IntervalsData.histDays();
        if (have > 0 && have < days) {
            days = have;
        }
        return days.toString() + "d";
    }

    // ---- page 0: form / fitness / fatigue -------------------------------

    hidden function drawFormPage(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        drawHeader(dc, "FORM");

        var wd = IntervalsData.wellness();
        if (wd == null) {
            drawEmptyState(dc);
            return;
        }

        // Hero number in the zone colour, the zone named under it, then the
        // two quantities form is the difference of, each with its history.
        var zone = IntervalsData.formZoneColor();
        IntervalsUi.drawFit(dc, cx, h * 27 / 100, IntervalsData.formText(),
            w * 50 / 100, w * 22 / 100, zone,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        IntervalsUi.drawFit(dc, cx, h * 395 / 1000, IntervalsData.formZoneLabel(),
            w * 64 / 100, IntervalsUi.px(dc, 85), zone,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Ramp rate is the weekly change in fitness, so it annotates that row.
        var ramp = wd["rampRate"];
        var rampStr = ramp == null ? ""
            : (ramp.toFloat() >= 0 ? "+" : "") + ramp.toFloat().format("%.1f") + "/wk";
        var rows = [
            ["FITNESS", rampStr, IntervalsData.fmt(wd["ctl"], 0),
                IntervalsCharts.CTL_COLOR, Graphics.COLOR_WHITE, recent("ctl", null), false, ""],
            ["FATIGUE", "", IntervalsData.fmt(wd["atl"], 0),
                IntervalsCharts.ATL_COLOR, Graphics.COLOR_WHITE, recent("atl", null), false, ""]
        ];
        IntervalsUi.drawTable(dc, rows, h * 45 / 100, h * 87 / 100);
    }

    // ---- page 1: fitness/fatigue over time-varying form-zone bands ------

    hidden function drawLoadPage(dc as Dc, round as Boolean) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        var ctl = IntervalsData.seriesZoomed("ctl");
        var atl = IntervalsData.seriesZoomed("atl");
        if (ctl == null || atl == null) {
            drawHeader(dc, "LOAD " + windowLabel());
            drawEmptyState(dc);
            return;
        }

        if (round) {
            drawLoadRing(dc, ctl, atl);
            return;
        }

        drawHeader(dc, "LOAD " + windowLabel());

        // Inset far enough that the axis labels left of the chart clear the
        // bezel at the chart's top corner.
        IntervalsCharts.drawLoadChart(dc, ctl, atl,
            w * 15 / 100, w * 90 / 100, h * 22 / 100, h * 72 / 100);

        // Legend with current values and the form zone chip.
        var wd = IntervalsData.wellness();
        var ly = h * 81 / 100;
        if (wd != null) {
            IntervalsUi.drawFit(dc, w * 26 / 100, ly,
                "Fit " + IntervalsData.fmt(wd["ctl"], 0), w * 30 / 100, w * 75 / 1000,
                IntervalsCharts.CTL_COLOR,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            IntervalsUi.drawFit(dc, w * 50 / 100, ly,
                "Fat " + IntervalsData.fmt(wd["atl"], 0), w * 30 / 100, w * 75 / 1000,
                IntervalsCharts.ATL_COLOR,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            IntervalsUi.drawFit(dc, w * 74 / 100, ly,
                "Form " + IntervalsData.formText(), w * 30 / 100, w * 75 / 1000,
                IntervalsData.formZoneColor(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // The polar load page: zone bands and CTL/ATL wrapped around the bezel,
    // with the form readout in the center.
    hidden function drawLoadRing(dc as Dc, ctl as Array, atl as Array) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        var rIn = w * 28 / 100;
        IntervalsCharts.drawPolarLoadChart(dc, ctl, atl,
            cx, cy, rIn, w * 47 / 100);

        var vc = Graphics.TEXT_JUSTIFY_VCENTER;
        IntervalsUi.drawFit(dc, cx, cy - h * 165 / 1000,
            busyLabel("LOAD " + windowLabel()),
            w * 42 / 100, IntervalsUi.px(dc, 80), IntervalsUi.DIM,
            Graphics.TEXT_JUSTIFY_CENTER | vc);

        // Fitness and fatigue flank form, each in its curve's colour, which
        // is all the labelling they need. The three share one size, the
        // largest at which the row clears the inner rim.
        var zone = IntervalsData.formZoneColor();
        var formStr = IntervalsData.formText();
        var wd = IntervalsData.wellness();
        var fitStr = wd != null ? IntervalsData.fmt(wd["ctl"], 0) : "";
        var fatStr = wd != null ? IntervalsData.fmt(wd["atl"], 0) : "";
        var ry = cy - h * 15 / 1000;
        var s = w * 17 / 100;
        var f = IntervalsUi.font(s);
        var mid = 0;
        var gap = 0;
        while (true) {
            f = IntervalsUi.font(s);
            mid = dc.getTextWidthInPixels(formStr, f) / 2;
            gap = s / 2;
            var side = dc.getTextWidthInPixels(fitStr, f);
            var fw = dc.getTextWidthInPixels(fatStr, f);
            if (fw > side) { side = fw; }
            var dy = s * 4 / 10;
            var half = Math.sqrt(rIn * rIn - dy * dy).toNumber() - w * 2 / 100;
            if (mid + gap + side <= half || s <= IntervalsUi.px(dc, IntervalsUi.TXT_HEAD)) {
                break;
            }
            s -= 2;
        }
        dc.setColor(zone, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, ry, f, formStr, Graphics.TEXT_JUSTIFY_CENTER | vc);
        dc.setColor(IntervalsCharts.CTL_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - mid - gap, ry, f, fitStr, Graphics.TEXT_JUSTIFY_RIGHT | vc);
        dc.setColor(IntervalsCharts.ATL_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + mid + gap, ry, f, fatStr, Graphics.TEXT_JUSTIFY_LEFT | vc);

        IntervalsUi.drawFit(dc, cx, cy + h * 125 / 1000, IntervalsData.formZoneLabel(),
            w * 46 / 100, IntervalsUi.px(dc, 80), zone,
            Graphics.TEXT_JUSTIFY_CENTER | vc);
    }

    // ---- configurable metric chart pages ---------------------------------

    hidden function drawMetricPage(dc as Dc, key as String, round as Boolean) as Void {
        if (round) {
            drawRingPage(dc, key);
            return;
        }

        var w = dc.getWidth();
        var h = dc.getHeight();
        var def = IntervalsCharts.defFor(key);
        var label = def[0] as String;
        var color = def[2] as Number;

        drawHeader(dc, label + " " + windowLabel());

        var values = IntervalsData.seriesZoomed(key);
        if (values == null) {
            drawEmptyState(dc);
            return;
        }

        var ok = IntervalsCharts.drawSeriesChart(dc, values, color,
            w * 16 / 100, w * 88 / 100, h * 22 / 100, h * 70 / 100,
            IntervalsCharts.hasBaseline(key));
        if (!ok) {
            drawMessage(dc, "No data in window");
            return;
        }

        // Current value plus the window's min/max.
        var dec = def[1] as Number;
        var cur = null;
        var minV = null;
        var maxV = null;
        for (var i = 0; i < values.size(); i++) {
            var v = values[i];
            if (v != null) {
                var f = v.toFloat();
                if (minV == null || f < minV) { minV = f; }
                if (maxV == null || f > maxV) { maxV = f; }
                cur = f;
            }
        }
        var fmtStr = "%." + dec + "f";
        IntervalsUi.drawFit(dc, w / 2, h * 77 / 100, cur.format(fmtStr),
            w * 42 / 100, w * 13 / 100, color,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        IntervalsUi.drawFit(dc, w / 2, h * 87 / 100,
            "min " + minV.format(fmtStr) + "   max " + maxV.format(fmtStr),
            w * 62 / 100, IntervalsUi.px(dc, IntervalsUi.TXT_LABEL), IntervalsUi.DIM,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ---- radial ring chart page -------------------------------------------

    hidden function drawRingPage(dc as Dc, key as String) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var def = IntervalsCharts.defFor(key);
        var label = def[0] as String;
        var dec = def[1] as Number;
        var color = def[2] as Number;

        var values = IntervalsData.seriesZoomed(key);
        if (values == null) {
            drawHeader(dc, label);
            drawEmptyState(dc);
            return;
        }

        var ok = IntervalsCharts.drawRingChart(dc, values, color,
            cx, cy, w * 28 / 100, w * 47 / 100,
            IntervalsCharts.hasBaseline(key));
        if (!ok) {
            drawHeader(dc, label);
            drawMessage(dc, "No data in window");
            return;
        }

        // The ring owns the bezel, so the readout lives in the center.
        var cur = null;
        var minV = null;
        var maxV = null;
        for (var i = 0; i < values.size(); i++) {
            var v = values[i];
            if (v != null) {
                var f = v.toFloat();
                if (minV == null || f < minV) { minV = f; }
                if (maxV == null || f > maxV) { maxV = f; }
                cur = f;
            }
        }
        var fmtStr = "%." + dec + "f";
        IntervalsUi.drawFit(dc, cx, cy - h * 175 / 1000,
            busyLabel(label),
            w * 46 / 100, IntervalsUi.px(dc, 80), color,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        IntervalsUi.drawFit(dc, cx, cy - h * 40 / 1000, cur.format(fmtStr),
            w * 48 / 100, w * 19 / 100, Graphics.COLOR_WHITE,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        IntervalsUi.drawFit(dc, cx, cy + h * 92 / 1000,
            minV.format(fmtStr) + " - " + maxV.format(fmtStr),
            w * 52 / 100, IntervalsUi.px(dc, 90), IntervalsUi.DIM,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        IntervalsUi.drawFit(dc, cx, cy + h * 182 / 1000, windowLabel(),
            w * 34 / 100, IntervalsUi.px(dc, 80), IntervalsUi.DIM,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ---- sparkline table pages --------------------------------------------

    // A data page is a table of its metrics' recent history (see
    // IntervalsUi.drawTable). Rows the athlete has no data for are left out
    // rather than shown as dashes, so the rows that remain can be large.
    hidden function drawSparkPage(dc as Dc, title as String, type as String) as Void {
        var h = dc.getHeight();
        drawHeader(dc, title);
        var wd = IntervalsData.wellness();
        if (wd == null) {
            drawEmptyState(dc);
            return;
        }
        // One Storage read per frame for every row's history.
        var sp = IntervalsCache.loadSpark();
        var keys = IntervalsApi.pageKeys(type);
        var rows = [];
        for (var i = 0; i < keys.size() && rows.size() < IntervalsUi.MAX_ROWS; i++) {
            var row = rowFor(keys[i], wd, recent(keys[i], sp));
            if (row != null) {
                rows.add(row);
            }
        }
        if (rows.size() == 0) {
            drawMessage(dc, "Nothing logged in\nthe last 30 days");
            return;
        }
        IntervalsUi.drawTable(dc, rows, h * 17 / 100, h * 87 / 100);
    }

    // The last SPARK_DAYS of a key's history, from the sparkline store or,
    // for a metric that is also on a graph page, the chart series.
    hidden function recent(key as String, sp as Dictionary?) as Array? {
        var a = sp != null ? sp[key] : null;
        if (!(a instanceof Lang.Array) || a.size() < 2) {
            a = IntervalsData.series(key);
        }
        if (a == null) {
            return null;
        }
        var n = IntervalsApi.SPARK_DAYS;
        if (a.size() <= n) {
            return a;
        }
        return a.slice(a.size() - n, null);
    }

    // Row kinds: how a metric's current value is written.
    const NUM = 0;
    const ORDINAL = 1;     // 1..4 subjective scale, as a word
    const DURATION = 2;    // seconds, as 7h31
    const PRESSURE = 3;    // systolic/diastolic

    // [label, unit, decimals, accent, kind] for a data-page metric key.
    hidden function rowDef(key as String) as Array {
        if (key.equals("restingHR")) { return ["REST HR", "bpm", 0, IntervalsUi.CORAL, NUM]; }
        if (key.equals("hrv")) { return ["HRV", "ms", 0, IntervalsUi.TEAL, NUM]; }
        if (key.equals("avgSleepingHR")) { return ["SLEEP HR", "bpm", 0, IntervalsUi.PINK, NUM]; }
        if (key.equals("readiness")) { return ["READINESS", "", 0, IntervalsUi.MINT, NUM]; }
        if (key.equals("hrvSDNN")) { return ["SDNN", "ms", 0, IntervalsUi.TEAL, NUM]; }
        if (key.equals("baevskySI")) { return ["STRESS IDX", "", 1, IntervalsUi.AMBER, NUM]; }
        if (key.equals("sleepSecs")) { return ["SLEEP", "", 0, IntervalsUi.VIOLET, DURATION]; }
        if (key.equals("sleepScore")) { return ["SCORE", "", 0, IntervalsUi.BLUE, NUM]; }
        if (key.equals("sleepQuality")) { return ["QUALITY", "", 0, IntervalsUi.VIOLET, ORDINAL]; }
        if (key.equals("respiration")) { return ["RESP", "brpm", 1, IntervalsUi.BLUE, NUM]; }
        if (key.equals("spO2")) { return ["SPO2", "%", 0, IntervalsUi.PINK, NUM]; }
        if (key.equals("weight")) { return ["WEIGHT", "kg", 1, IntervalsUi.AMBER, NUM]; }
        if (key.equals("bodyFat")) { return ["BODY FAT", "%", 1, IntervalsUi.AMBER, NUM]; }
        if (key.equals("vo2max")) { return ["VO2MAX", "", 1, IntervalsUi.MINT, NUM]; }
        if (key.equals("systolic")) { return ["BP", "mmHg", 0, IntervalsUi.CORAL, PRESSURE]; }
        if (key.equals("bloodGlucose")) { return ["GLUCOSE", "", 1, IntervalsUi.PINK, NUM]; }
        if (key.equals("steps")) { return ["STEPS", "", 0, IntervalsUi.MINT, NUM]; }
        if (key.equals("kcalConsumed")) { return ["CALORIES", "kcal", 0, IntervalsUi.AMBER, NUM]; }
        if (key.equals("carbohydrates")) { return ["CARBS", "g", 0, IntervalsUi.LIME, NUM]; }
        if (key.equals("protein")) { return ["PROTEIN", "g", 0, IntervalsUi.BLUE, NUM]; }
        if (key.equals("fatTotal")) { return ["FAT", "g", 0, IntervalsUi.PINK, NUM]; }
        if (key.equals("hydrationVolume")) { return ["WATER", "l", 1, IntervalsUi.TEAL, NUM]; }
        // The subjective scales: colour belongs to the value's severity, so
        // the labels stay neutral.
        return [key.toUpper(), "", 0, IntervalsUi.SLATE, ORDINAL];
    }

    // A table row for one metric, or null when there is nothing to show:
    // no current value and no history in the window.
    hidden function rowFor(key as String, wd as Dictionary, series as Array?) as Array? {
        var v = wd[key];
        if (series != null && !hasValue(series)) {
            series = null;
        }
        if (v == null && series == null) {
            return null;
        }
        var def = rowDef(key);
        var kind = def[4] as Number;
        var text;
        var color = Graphics.COLOR_WHITE;
        if (kind == ORDINAL) {
            text = scaleWord(v);
            color = IntervalsUi.severityColor(v);
        } else if (kind == DURATION) {
            text = IntervalsData.fmtSleep(v);
        } else if (kind == PRESSURE) {
            text = v != null && wd["diastolic"] != null
                ? v.format("%d") + "/" + wd["diastolic"].format("%d") : "--";
        } else {
            text = IntervalsData.fmt(v, def[2] as Number);
        }
        return [def[0], def[1], text, def[3], color, series, kind == ORDINAL,
            rangeText(series, kind, def[2] as Number)];
    }

    // "30d: lo - hi" over a row's history, for the single-metric layout;
    // empty for scales and pairs, or when there is no spread to report.
    hidden function rangeText(series as Array?, kind as Number, dec as Number) as String {
        if (series == null || kind == ORDINAL || kind == PRESSURE) {
            return "";
        }
        var lo = null;
        var hi = null;
        for (var i = 0; i < series.size(); i++) {
            var v = series[i];
            if (v != null) {
                if (lo == null || v < lo) { lo = v; }
                if (hi == null || v > hi) { hi = v; }
            }
        }
        if (lo == null || lo == hi) {
            return "";
        }
        var a = kind == DURATION ? IntervalsData.fmtSleep(lo) : IntervalsData.fmt(lo, dec);
        var b = kind == DURATION ? IntervalsData.fmtSleep(hi) : IntervalsData.fmt(hi, dec);
        return IntervalsApi.SPARK_DAYS + "d: " + a + " - " + b;
    }

    hidden function hasValue(a as Array) as Boolean {
        for (var i = 0; i < a.size(); i++) {
            if (a[i] != null) {
                return true;
            }
        }
        return false;
    }

    // ---- status ------------------------------------------------------------

    hidden function drawStatusPage(dc as Dc) as Void {
        var h = dc.getHeight();
        drawHeader(dc, "STATUS");
        var err = IntervalsData.lastError();
        var age = IntervalsData.ageText();
        if (IntervalsData.ageSecs() != null && !age.equals("now")) {
            age += " ago";
        }
        var items = [
            ["UPDATED", age, Graphics.COLOR_WHITE],
            ["DATA FROM", dataDate(), Graphics.COLOR_WHITE],
            authItem(),
            ["ATHLETE", IntervalsSettings.athleteId(), Graphics.COLOR_WHITE],
            ["VERSION", "0.12.0", Graphics.COLOR_WHITE],
            ["STATUS", err != null ? err : "OK",
                err != null ? IntervalsUi.CORAL : IntervalsUi.MINT]
        ];
        // Leave the bottom clear for the link prompt when it shows.
        var linked = IntervalsSettings.oauthToken() != null;
        IntervalsUi.drawPairs(dc, items, h * 17 / 100, linked ? h * 87 / 100 : h * 82 / 100);
        drawLinkHint(dc);
    }

    // OAuth (mint) / legacy API key (amber) / not connected (coral).
    hidden function authItem() as Array {
        if (IntervalsSettings.oauthToken() != null) {
            return ["AUTH", "OAuth", IntervalsUi.MINT];
        }
        if (IntervalsSettings.apiKey() != null) {
            return ["AUTH", "API key", IntervalsUi.AMBER];
        }
        return ["AUTH", "none", IntervalsUi.CORAL];
    }

    hidden function dataDate() as String {
        var w = IntervalsData.wellness();
        if (w != null && w["_date"] instanceof Lang.String) {
            return w["_date"];
        }
        return "--";
    }

    hidden function scaleWord(v) as String {
        if (v == null) {
            return "--";
        }
        var words = ["Good", "OK", "Poor", "Bad"] as Array<String>;
        var i = v.toNumber() - 1;
        if (i < 0 || i > 3) {
            return v.format("%d");
        }
        return words[i];
    }

    // ---- shared chrome ----------------------------------------------------

    hidden function drawHeader(dc as Dc, title as String) as Void {
        IntervalsUi.drawFit(dc, dc.getWidth() / 2, dc.getHeight() * 11 / 100,
            busyLabel(title),
            dc.getWidth() * 66 / 100, IntervalsUi.px(dc, IntervalsUi.TXT_HEAD), 0x55AAFF,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    hidden function drawEmptyState(dc as Dc) as Void {
        var msg;
        if (IntervalsAuth.busy()) {
            // Garmin's OAuth flow happens in the phone app; the docs require
            // pointing the user there.
            msg = "Open Garmin Connect\non your phone to sign in";
        } else if (!IntervalsSettings.isConnected()) {
            msg = "Press START to connect\nintervals.icu";
        } else {
            var err = IntervalsData.lastError();
            msg = err != null ? err : "Waiting for data...\nPress START to sync";
        }
        drawMessage(dc, msg);
    }

    // Centred grey notice, set like the page headers.
    hidden function drawMessage(dc as Dc, msg as String) as Void {
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2,
            IntervalsUi.font(IntervalsUi.px(dc, IntervalsUi.TXT_HEAD)), msg,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    hidden function drawPageDots(dc as Dc, count as Number) as Void {
        var w = dc.getWidth();
        var y = dc.getHeight() * 94 / 100;
        var spacing = count > 9 ? 12 : 14;
        var x0 = w / 2 - spacing * (count - 1) / 2;
        for (var i = 0; i < count; i++) {
            if (i == _page) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x0 + i * spacing, y, 3);
            } else {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x0 + i * spacing, y, 2);
            }
        }
    }
}

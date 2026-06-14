import Toybox.Graphics;
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
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var pages = IntervalsPages.list();
        var id = pages[_page < pages.size() ? _page : 0] as String;

        if (id.equals("form")) {
            drawFormPage(dc);
        } else if (id.equals("load")) {
            drawLoadPage(dc);
        } else if (id.find("chart:") == 0) {
            drawChartPage(dc, id.substring(6, id.length()));
        } else if (id.find("ring:") == 0) {
            drawRingPage(dc, id.substring(5, id.length()));
        } else if (id.equals("recovery")) {
            drawTilesPage(dc, "RECOVERY", recoveryItems());
        } else if (id.equals("sleep")) {
            drawTilesPage(dc, "SLEEP", sleepItems());
        } else if (id.equals("body")) {
            drawTilesPage(dc, "BODY", bodyItems());
        } else if (id.equals("fuel")) {
            drawTilesPage(dc, "FUEL + STEPS", fuelItems());
        } else if (id.equals("feel")) {
            drawTilesPage(dc, "HOW YOU FEEL", feelItems());
        } else {
            drawTilesPage(dc, "STATUS", statusItems());
        }

        if (IntervalsRefresh.zoomActive && IntervalsPages.isChart(id)) {
            drawZoomOverlay(dc);
        } else {
            drawPageDots(dc, pages.size());
        }
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

    hidden function windowLabel() as String {
        return IntervalsData.zoomDays().toString() + "d";
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

        // Hero number, auto-fitted, in the zone color.
        var zone = IntervalsData.formZoneColor();
        IntervalsUi.drawFit(dc, cx, h * 38 / 100, IntervalsData.formText(),
            w * 60 / 100, w * 31 / 100, zone,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        IntervalsUi.drawFit(dc, cx, h * 57 / 100, IntervalsData.formZoneLabel(),
            w * 54 / 100, w * 75 / 1000, zone,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Mini tiles for the load numbers.
        var ramp = wd["rampRate"];
        var rampStr = ramp == null ? "--"
            : (ramp.toFloat() >= 0 ? "+" : "") + ramp.toFloat().format("%.1f");
        var labels = ["FITNESS", "FATIGUE", "RAMP"] as Array<String>;
        var values = [
            IntervalsData.fmt(wd["ctl"], 0),
            IntervalsData.fmt(wd["atl"], 0),
            rampStr
        ] as Array<String>;
        var colors = [IntervalsCharts.CTL_COLOR, IntervalsCharts.ATL_COLOR,
            Graphics.COLOR_WHITE] as Array<Number>;

        var y = h * 72 / 100;
        for (var i = 0; i < 3; i++) {
            var x = w * (i * 28 + 22) / 100;
            IntervalsUi.drawFit(dc, x, y, values[i], w * 27 / 100, w * 11 / 100, colors[i],
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(IntervalsUi.DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y + w * 84 / 1000, IntervalsUi.font(w * 44 / 1000), labels[i],
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // ---- page 1: fitness/fatigue over time-varying form-zone bands ------

    hidden function drawLoadPage(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        var ctl = IntervalsData.seriesZoomed("ctl");
        var atl = IntervalsData.seriesZoomed("atl");
        if (ctl == null || atl == null) {
            drawHeader(dc, "LOAD " + windowLabel());
            drawEmptyState(dc);
            return;
        }

        if (IntervalsSettings.roundCharts()) {
            drawLoadRing(dc, ctl, atl);
            return;
        }

        drawHeader(dc, "LOAD " + windowLabel());

        IntervalsCharts.drawLoadChart(dc, ctl, atl,
            w * 10 / 100, w * 90 / 100, h * 22 / 100, h * 72 / 100);

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

        IntervalsCharts.drawPolarLoadChart(dc, ctl, atl,
            cx, cy, w * 28 / 100, w * 47 / 100);

        var zone = IntervalsData.formZoneColor();
        IntervalsUi.drawFit(dc, cx, cy - h * 172 / 1000,
            IntervalsRefresh.isBusy() ? "SYNCING..." : "LOAD " + windowLabel(),
            w * 42 / 100, w * 53 / 1000, IntervalsUi.DIM,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        IntervalsUi.drawFit(dc, cx, cy - h * 31 / 1000, IntervalsData.formText(),
            w * 46 / 100, w * 19 / 100, zone,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        IntervalsUi.drawFit(dc, cx, cy + h * 97 / 1000, IntervalsData.formZoneLabel(),
            w * 42 / 100, w * 62 / 1000, zone,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var wd = IntervalsData.wellness();
        if (wd != null) {
            IntervalsUi.drawFit(dc, cx - w * 11 / 100, cy + h * 176 / 1000,
                "Fit " + IntervalsData.fmt(wd["ctl"], 0), w * 20 / 100, w * 75 / 1000,
                IntervalsCharts.CTL_COLOR,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            IntervalsUi.drawFit(dc, cx + w * 11 / 100, cy + h * 176 / 1000,
                "Fat " + IntervalsData.fmt(wd["atl"], 0), w * 20 / 100, w * 75 / 1000,
                IntervalsCharts.ATL_COLOR,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // ---- configurable metric chart pages ---------------------------------

    hidden function drawChartPage(dc as Dc, key as String) as Void {
        if (IntervalsSettings.roundCharts()) {
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
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h / 2, Graphics.FONT_SMALL, "No data in window",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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
            "min " + minV.format(fmtStr) + "    max " + maxV.format(fmtStr),
            w * 58 / 100, w * 53 / 1000, IntervalsUi.DIM,
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
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_SMALL, "No data in window",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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
        IntervalsUi.drawFit(dc, cx, cy - h * 172 / 1000,
            IntervalsRefresh.isBusy() ? "SYNCING..." : label,
            w * 42 / 100, w * 62 / 1000, color,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        IntervalsUi.drawFit(dc, cx, cy - h * 18 / 1000, cur.format(fmtStr),
            w * 50 / 100, w * 22 / 100, Graphics.COLOR_WHITE,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        IntervalsUi.drawFit(dc, cx, cy + h * 123 / 1000,
            minV.format(fmtStr) + " - " + maxV.format(fmtStr),
            w * 42 / 100, w * 57 / 1000, IntervalsUi.DIM,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        IntervalsUi.drawFit(dc, cx, cy + h * 185 / 1000, windowLabel(),
            w * 30 / 100, w * 48 / 1000, IntervalsUi.DIM,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ---- stat tile pages --------------------------------------------------

    hidden function drawTilesPage(dc as Dc, title as String, items as Array) as Void {
        drawHeader(dc, title);
        if (items.size() == 0) {
            drawEmptyState(dc);
            return;
        }
        IntervalsUi.drawTiles(dc, items);
    }

    hidden function recoveryItems() as Array {
        var w = IntervalsData.wellness();
        if (w == null) { return []; }
        return [
            ["REST HR", IntervalsData.fmt(w["restingHR"], 0), "bpm", IntervalsUi.CORAL],
            ["HRV", IntervalsData.fmt(w["hrv"], 0), "ms", IntervalsUi.TEAL],
            ["SDNN", IntervalsData.fmt(w["hrvSDNN"], 0), "ms", IntervalsUi.TEAL],
            ["SLEEP HR", IntervalsData.fmt(w["avgSleepingHR"], 0), "bpm", IntervalsUi.PINK],
            ["READINESS", IntervalsData.fmt(w["readiness"], 0), "", IntervalsUi.MINT],
            ["STRESS IDX", IntervalsData.fmt(w["baevskySI"], 1), "", IntervalsUi.AMBER]
        ];
    }

    hidden function sleepItems() as Array {
        var w = IntervalsData.wellness();
        if (w == null) { return []; }
        return [
            ["SLEEP", IntervalsData.fmtSleep(w["sleepSecs"]), "", IntervalsUi.VIOLET],
            ["SCORE", IntervalsData.fmt(w["sleepScore"], 0), "", IntervalsUi.BLUE],
            ["QUALITY", scaleWord(w["sleepQuality"]), scaleUnit(w["sleepQuality"]), IntervalsUi.VIOLET],
            ["RESP", IntervalsData.fmt(w["respiration"], 1), "brpm", IntervalsUi.BLUE],
            ["SPO2", IntervalsData.fmt(w["spO2"], 0), w["spO2"] == null ? "" : "%", IntervalsUi.PINK]
        ];
    }

    hidden function bodyItems() as Array {
        var w = IntervalsData.wellness();
        if (w == null) { return []; }
        var bp = "--";
        if (w["systolic"] != null && w["diastolic"] != null) {
            bp = w["systolic"].format("%d") + "/" + w["diastolic"].format("%d");
        }
        return [
            ["WEIGHT", IntervalsData.fmt(w["weight"], 1), w["weight"] == null ? "" : "kg", IntervalsUi.AMBER],
            ["BODY FAT", IntervalsData.fmt(w["bodyFat"], 1), w["bodyFat"] == null ? "" : "%", IntervalsUi.AMBER],
            ["VO2MAX", IntervalsData.fmt(w["vo2max"], 1), "", IntervalsUi.MINT],
            ["BP", bp, "", IntervalsUi.CORAL],
            ["GLUCOSE", IntervalsData.fmt(w["bloodGlucose"], 1), "", IntervalsUi.PINK]
        ];
    }

    hidden function fuelItems() as Array {
        var w = IntervalsData.wellness();
        if (w == null) { return []; }
        return [
            ["CALORIES", IntervalsData.fmt(w["kcalConsumed"], 0), "", IntervalsUi.AMBER],
            ["CARBS", IntervalsData.fmt(w["carbohydrates"], 0), grams(w["carbohydrates"]), IntervalsUi.LIME],
            ["PROTEIN", IntervalsData.fmt(w["protein"], 0), grams(w["protein"]), IntervalsUi.BLUE],
            ["FAT", IntervalsData.fmt(w["fatTotal"], 0), grams(w["fatTotal"]), IntervalsUi.PINK],
            ["WATER", IntervalsData.fmt(w["hydrationVolume"], 1), w["hydrationVolume"] == null ? "" : "l", IntervalsUi.TEAL],
            ["STEPS", IntervalsData.fmt(w["steps"], 0), "", IntervalsUi.MINT]
        ];
    }

    hidden function feelItems() as Array {
        var w = IntervalsData.wellness();
        if (w == null) { return []; }
        return [
            feelItem("FATIGUE", w["fatigue"]),
            feelItem("SORENESS", w["soreness"]),
            feelItem("STRESS", w["stress"]),
            feelItem("MOOD", w["mood"]),
            feelItem("MOTIVATION", w["motivation"]),
            feelItem("INJURY", w["injury"])
        ];
    }

    // Subjective 1 (best) .. 4 (worst): word value tinted by severity.
    hidden function feelItem(label as String, v) as Array {
        var colors = [IntervalsUi.MINT, IntervalsUi.BLUE,
            IntervalsUi.AMBER, IntervalsUi.CORAL] as Array<Number>;
        var color = Graphics.COLOR_WHITE;
        var i = v == null ? -1 : v.toNumber() - 1;
        if (i >= 0 && i <= 3) {
            color = colors[i];
        }
        return [label, scaleWord(v), scaleUnit(v), IntervalsUi.SLATE, color];
    }

    hidden function statusItems() as Array {
        var err = IntervalsData.lastError();
        return [
            ["UPDATED", IntervalsData.ageText(), "ago", IntervalsUi.SLATE],
            ["ATHLETE", IntervalsSettings.athleteId(), "", IntervalsUi.SLATE],
            ["API KEY", IntervalsSettings.apiKey() != null ? "set" : "missing", "", IntervalsUi.SLATE],
            ["STATUS", err != null ? err : "OK", "",
                IntervalsUi.SLATE, err != null ? IntervalsUi.CORAL : IntervalsUi.MINT],
            ["DATA FROM", dataDate(), "", IntervalsUi.SLATE],
            ["VERSION", "0.8.0", "", IntervalsUi.SLATE]
        ];
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

    hidden function scaleUnit(v) as String {
        if (v == null) {
            return "";
        }
        return v.format("%d") + "/4";
    }

    hidden function grams(v) as String {
        return v == null ? "" : "g";
    }

    // ---- shared chrome ----------------------------------------------------

    hidden function drawHeader(dc as Dc, title as String) as Void {
        IntervalsUi.drawFit(dc, dc.getWidth() / 2, dc.getHeight() * 11 / 100,
            IntervalsRefresh.isBusy() ? "SYNCING..." : title,
            dc.getWidth() * 62 / 100, dc.getWidth() * 57 / 1000, 0x55AAFF,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    hidden function drawEmptyState(dc as Dc) as Void {
        var msg;
        if (IntervalsSettings.apiKey() == null) {
            msg = "Set API key in\nConnect IQ settings";
        } else {
            var err = IntervalsData.lastError();
            msg = err != null ? err : "Waiting for data...\nPress START to sync";
        }
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_SMALL,
            msg, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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

import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Day-index arithmetic, split out of IntervalsApi so that glance code needing
// a day index does not drag the whole request-building module into the glance
// memory image (which the system loads every time the glance takes focus).
(:background :glance)
module IntervalsDays {

    // Noon-shifted so a day index is stable across DST transitions.
    function dayIdxOf(moment as Time.Moment) as Number {
        return (moment.value() + 43200) / 86400;
    }

    function todayIdx() as Number {
        return dayIdxOf(Time.today());
    }

    function dayIdxOfDate(s) as Number? {
        if (!(s instanceof Lang.String) || s.length() < 10) {
            return null;
        }
        var y = s.substring(0, 4).toNumber();
        var m = s.substring(5, 7).toNumber();
        var d = s.substring(8, 10).toNumber();
        if (y == null || m == null || d == null) {
            return null;
        }
        return dayIdxOf(Gregorian.moment({ :year => y, :month => m, :day => d }));
    }
}

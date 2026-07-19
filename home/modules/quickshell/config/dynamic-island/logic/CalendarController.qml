import QtQuick
import ".."

// Calendar behavior: which year the grid shows, year-step navigation, date math.
// View owns the ContentSlide; it calls beginNavigate to accumulate the target,
// commitNavigate at the swap midpoint. No visuals here.
QtObject {
    id: root

    // Grid year tracks todayYear, so a midnight rollover into a new year carries the
    // grid with it, until the user navigates to some other year: that one is absolute
    // and pins. Back to the current year unpins.
    readonly property int displayYear: _yearPinned ? _pinnedYear : todayYear
    property bool _yearPinned: false
    property int _pinnedYear: 0
    property int _targetYear: 0
    // displayYear catches up only on commitNavigate.
    // Steps before then accumulate onto the in-flight target, else clicks drop years.
    property bool _transitioning: false

    readonly property var today: Clock.date
    readonly property int todayYear: today.getFullYear()
    readonly property int todayMonth: today.getMonth()
    readonly property int todayDay: today.getDate()
    readonly property var germanLocale: Qt.locale("de_DE")

    // Accumulate the year step. View drives the slide with the sign of direction.
    function beginNavigate(direction) {
        _targetYear = (_transitioning ? _targetYear : displayYear) + direction;
        _transitioning = true;
    }

    // Swap midpoint reached. Land displayYear on the accumulated target.
    function commitNavigate() {
        _pinnedYear = _targetYear;
        _yearPinned = _targetYear !== todayYear;
        _transitioning = false;
    }

    function getDaysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate();
    }

    function getFirstDayOffset(year, month) {
        return (new Date(year, month, 1).getDay() + 6) % 7;
    }

    function getIsoWeekNumber(year, month, day) {
        var dt = new Date(year, month, day);
        dt.setHours(0, 0, 0, 0);
        dt.setDate(dt.getDate() + 3 - (dt.getDay() + 6) % 7);
        var y1 = new Date(dt.getFullYear(), 0, 4);
        return 1 + Math.round(((dt - y1) / 86400000 - 3 + (y1.getDay() + 6) % 7) / 7);
    }
}

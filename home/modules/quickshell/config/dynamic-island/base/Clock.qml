pragma Singleton

import QtQuick
import Quickshell

// Wall-clock source for every time-dependent widget. Widgets are constructed once
// and live for the whole session, so a captured `new Date()` freezes at startup and
// never rolls over at midnight. Binding to `Clock.date` instead keeps the bar clock
// and the calendar's notion of "today" on the same tick.
//
// Minute precision is the finest resolution anything displays.
Singleton {
    id: root

    readonly property var date: clock.date

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Events of one year, read from evolution-data-server through calendar_events.py.
// Singleton: the calendars are machine-global, the calendar menu is per screen.
//
// One shot per read, holding only the year on screen. A menu open or a year step
// re-runs the helper, so the registry stays the only owner of what exists and no
// copy here can go stale.
//
// One year at a time. Menus are hover-driven and one pointer opens one of them,
// so two screens asking for different years at once does not arise.
//
// A failed read leaves the year empty and puts nothing on screen. Helper warnings
// reach the shell log unparsed, which is the whole report: a calendar that goes
// blank while the user knows tomorrow holds an appointment reports itself.
Singleton {
    id: root

    // "YYYY-MM-DD" -> [{ summary, allDay, start, end, calendar }].
    // Helper sorts each day: all-day first, then by start.
    property var days: ({})
    // Calendar uid -> { name, color }. color is "#rrggbb", or "" when the source names none.
    property var calendars: ({})
    // Year `days` holds. 0 before the first successful read.
    property int year: 0

    // Year the menu shows. Written by the menu; a change refetches.
    property int requestedYear: 0
    onRequestedYearChanged: {
        // Clear first, else a failed read leaves another year's events on the grid.
        if (root.requestedYear !== root.year)
            root.days = ({});
        root.refresh();
    }

    // True while a calendar menu is open. Drives the fetch. Set from the Bar.
    property bool menuOpen: false
    function setMenuOpen(open) {
        root.menuOpen = open;
        if (open)
            root.refresh();
    }

    readonly property string _script: Qt.resolvedUrl("../calendar_events.py").toString().replace("file://", "")

    function dateKey(year, monthIndex, day) {
        return year + "-" + ("0" + (monthIndex + 1)).slice(-2) + "-" + ("0" + day).slice(-2);
    }

    function eventsOn(key) {
        return root.days[key] || [];
    }

    // Distinct calendar uids on a day, in the order their events sort, capped at max.
    // Caller resolves each to a colour, so a calendar with no colour still marks the day.
    function calendarsOn(key, max) {
        const events = root.days[key];
        if (!events)
            return [];
        const uids = [];
        for (let i = 0; i < events.length && uids.length < max; i++) {
            const uid = events[i].calendar;
            if (uids.indexOf(uid) === -1)
                uids.push(uid);
        }
        return uids;
    }

    function calendarColor(uid) {
        return (root.calendars[uid] || {}).color || "";
    }

    // Re-reads the requested year. Repeat calls while a read is in flight do nothing,
    // and a read of an unchanged year writes back the same values.
    function refresh() {
        if (fetchProc.running || root.requestedYear === 0)
            return;
        fetchProc.command = ["python3", root._script, String(root.requestedYear)];
        fetchProc.running = true;
    }

    Process {
        id: fetchProc

        stdout: StdioCollector {
            id: fetchOut
            onStreamFinished: {
                try {
                    const payload = JSON.parse(fetchOut.text);
                    root.calendars = payload.calendars || ({});
                    root.days = payload.days || ({});
                    root.year = payload.year || 0;
                } catch (e) {
                    // Helper printed nothing usable. Grid keeps whatever it holds.
                }
            }
        }
        // stderr carries no parser on purpose, so helper warnings land in the shell log.
    }
}

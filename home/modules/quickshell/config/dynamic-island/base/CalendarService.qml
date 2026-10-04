pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Events of one year, read from evolution-data-server through calendar_events.py.
// Singleton: the calendars are machine-global, the calendar menu is per screen.
//
// Helper starts at the first menu open and runs for the shell's lifetime.
// Its open clients keep the calendar backends alive, so a server pull runs to the end
// and the backends' own refresh timers keep firing between opens.
// Every menu open asks for a pull on top.
// Helper writes a fresh payload per change, from the local cache first, then again
// once the pull lands, so the registry stays the only owner of what exists.
//
// One year at a time. Menus are hover-driven and one pointer opens one of them,
// so two screens asking for different years at once does not arise.
//
// A calendar that fails to read drops out of the payload and puts nothing on screen.
// Helper warnings reach the shell log unparsed, which is the whole report: a calendar
// that goes blank while the user knows tomorrow holds an appointment reports itself.
Singleton {
    id: root

    // "YYYY-MM-DD" -> [{ summary, allDay, start, end, calendar }].
    // Helper sorts each day: all-day first, then by start.
    property var days: ({})
    // Calendar uid -> { name, color }. color is "#rrggbb", or "" when the source names none.
    property var calendars: ({})
    // Year `days` holds. 0 before the first successful read.
    property int year: 0

    // Year the menu shows. Written by the menu; a change asks the helper for that year.
    property int requestedYear: 0
    onRequestedYearChanged: {
        // Clear first, else a failed read leaves another year's events on the grid.
        if (root.requestedYear !== root.year)
            root.days = ({});
        root._sendYear();
    }

    // True while a calendar menu is open. Set from the Bar.
    property bool menuOpen: false
    function setMenuOpen(open) {
        root.menuOpen = open;
        if (open)
            root.refresh();
    }

    readonly property string _script: Qt.resolvedUrl("../calendar_events.py").toString().replace("file://", "")
    readonly property string _newEventScript: Qt.resolvedUrl("../calendar_new_event.sh").toString().replace("file://", "")

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

    // Opens GNOME Calendar's new-event editor on that day.
    // Saved event reaches the grid as a helper payload.
    function createEventOn(key) {
        const parts = key.split("-");
        Quickshell.execDetached(["bash", root._newEventScript, parts[1] + "/" + parts[2] + "/" + parts[0]]);
    }

    // Pulls every calendar from its server, starting the helper on first use.
    // Changes arrive as further payloads.
    function refresh() {
        if (!helper.running) {
            // onStarted sends the year and the pull.
            helper.running = true;
            return;
        }
        helper.write("refresh\n");
    }

    function _sendYear() {
        if (helper.running && root.requestedYear !== 0)
            helper.write(root.requestedYear + "\n");
    }

    function _apply(line) {
        let payload;
        try {
            payload = JSON.parse(line);
        } catch (e) {
            // Helper printed nothing usable. Grid keeps whatever it holds.
            return;
        }
        // Payload of a year the menu has since left.
        if (payload.year !== root.requestedYear)
            return;
        root.calendars = payload.calendars || ({});
        root.days = payload.days || ({});
        root.year = payload.year;
    }

    // Exit stops the event updates until the next menu open restarts it.
    Process {
        id: helper
        command: ["python3", root._script]
        stdinEnabled: true

        onStarted: {
            root._sendYear();
            helper.write("refresh\n");
        }

        // One JSON payload per line.
        stdout: SplitParser {
            onRead: line => root._apply(line)
        }
        // stderr carries no parser on purpose, so helper warnings land in the shell log.
    }
}

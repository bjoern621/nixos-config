#!/usr/bin/env python3
"""One year of calendar events, read from evolution-data-server.

Usage: calendar_events.py <year>

Prints one JSON object on stdout: the enabled calendars, and their events keyed
by ISO date. Reads every enabled calendar source with no filter, since the
Radicale collection owns which calendars exist and the registry owns which are on.

Every failure here is an environment failure: unreachable relay, no registry,
a calendar that refuses to open. Warning on stderr, valid empty payload on
stdout, exit 1. The shell stays silent about it by design.
"""

import json
import sys
from datetime import date, datetime, timedelta

import gi

gi.require_version("EDataServer", "1.2")
gi.require_version("ECal", "2.0")

from gi.repository import ECal, EDataServer  # noqa: E402

# (guint32) -1 skips connect_sync's wait for the backend to report connected.
# CalDAV sources here stay disconnected,
# so a finite wait burns its full length per calendar,
# and 0 arms no timeout and blocks forever.
# generate_instances_sync reads the backend's local cache either way.
SKIP_CONNECTED_WAIT = 0xFFFFFFFF


def warn(message):
    print("calendar_events: " + message, file=sys.stderr)


def iso(day):
    return day.isoformat()


def clock(itime):
    return "%02d:%02d" % (itime.get_hour(), itime.get_minute())


def as_date(itime):
    return date(itime.get_year(), itime.get_month(), itime.get_day())


def covered_days(start, end, all_day, first_of_year, last_of_year):
    """Days an instance occupies, clamped to the requested year.

    DTEND is exclusive, so an instance ending at midnight leaves the end day free.
    """
    first = as_date(start)
    last = as_date(end)
    ends_at_midnight = end.get_hour() == 0 and end.get_minute() == 0
    if last > first and (all_day or ends_at_midnight):
        last -= timedelta(days=1)
    if last < first:
        last = first
    first = max(first, first_of_year)
    last = min(last, last_of_year)
    while first <= last:
        yield first
        first += timedelta(days=1)


def hex_color(color):
    """#RRGGBB, or "" when the source names no colour QML can read.

    Registry normalises a server's #RRGGBBAA to #RRGGBB, and writes rgb(r,g,b)
    for a colour picked in a client.
    """
    color = (color or "").strip()
    if color.startswith("#") and len(color) == 7:
        return color
    if color.startswith("rgb(") and color.endswith(")"):
        try:
            parts = [int(p) for p in color[4:-1].split(",")]
        except ValueError:
            return ""
        if len(parts) == 3 and all(0 <= p <= 255 for p in parts):
            return "#%02x%02x%02x" % tuple(parts)
    return ""


def calendar_entry(source):
    extension = source.get_extension(EDataServer.SOURCE_EXTENSION_CALENDAR)
    return {
        "name": source.get_display_name(),
        "color": hex_color(extension.get_color()),
    }


def read_source(source, year, days):
    """Append one calendar's instances to days. Returns False on an unusable calendar."""
    try:
        client = ECal.Client.connect_sync(
            source, ECal.ClientSourceType.EVENTS, SKIP_CONNECTED_WAIT, None
        )
    except Exception as error:
        warn("calendar %r did not open: %s" % (source.get_display_name(), error))
        return False

    client.set_default_timezone(ECal.util_get_system_timezone())

    uid = source.get_uid()
    first_of_year = date(year, 1, 1)
    last_of_year = date(year, 12, 31)
    # Naive datetimes, so timestamp() reads them in the machine's zone.
    window_start = int(datetime(year, 1, 1).timestamp())
    window_end = int(datetime(year + 1, 1, 1).timestamp())

    def on_instance(icomp, start, end, *_rest):
        all_day = start.is_date()
        event = {
            "summary": icomp.get_summary() or "",
            "allDay": all_day,
            "start": "" if all_day else clock(start),
            "end": "" if all_day else clock(end),
            "calendar": uid,
        }
        for day in covered_days(start, end, all_day, first_of_year, last_of_year):
            days.setdefault(iso(day), []).append(event)
        return True

    try:
        client.generate_instances_sync(window_start, window_end, None, on_instance)
    except Exception as error:
        warn("calendar %r did not read: %s" % (source.get_display_name(), error))
        return False
    return True


def sort_key(event):
    # All-day first, then by start. Ties fall back to the title for a stable order.
    return (0 if event["allDay"] else 1, event["start"], event["summary"])


def main(argv):
    payload = {"year": 0, "calendars": {}, "days": {}}
    if len(argv) != 2:
        warn("usage: calendar_events.py <year>")
        print(json.dumps(payload))
        return 1

    try:
        year = int(argv[1])
    except ValueError:
        warn("year %r is not a number" % argv[1])
        print(json.dumps(payload))
        return 1
    payload["year"] = year

    try:
        registry = EDataServer.SourceRegistry.new_sync(None)
    except Exception as error:
        warn("registry unavailable: %s" % error)
        print(json.dumps(payload))
        return 1

    days = {}
    complete = True
    for source in registry.list_enabled(EDataServer.SOURCE_EXTENSION_CALENDAR):
        payload["calendars"][source.get_uid()] = calendar_entry(source)
        complete &= read_source(source, year, days)

    for events in days.values():
        events.sort(key=sort_key)
    payload["days"] = days

    print(json.dumps(payload))
    return 0 if complete else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))

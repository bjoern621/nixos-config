#!/usr/bin/env python3
"""Calendar events from evolution-data-server, for the lifetime of the shell.

Usage: calendar_events.py

Reads commands from stdin, one per line:
  <year>    year to report, e.g. "2026"
  refresh   pull every calendar and account from its server

Writes one JSON object per line on stdout: the enabled calendars, and the
requested year's events keyed by ISO date. A new line follows every change,
from a command, a server pull or an edit in another client.
Identical payloads are written once.

Holds a client open on every enabled calendar source.
Calendar factory closes a backend once its last client leaves,
aborting any server pull in flight,
so a helper exiting after one read would only ever see the local cache.

Every failure here is an environment failure: no registry, a calendar that
refuses to open, an unreachable server. Warning on stderr, the calendar in
question left out. The shell stays silent about it by design.
Exits when stdin closes.
"""

import json
import sys
from datetime import date, datetime, timedelta

import gi

gi.require_version("EDataServer", "1.2")
gi.require_version("ECal", "2.0")
gi.require_version("GioUnix", "2.0")

from gi.repository import ECal, EDataServer, Gio, GioUnix, GLib  # noqa: E402

# (guint32) -1 skips connect's wait for the backend to report connected.
# Waiting holds every read back until the server answers,
# and 0 arms no timeout and waits forever.
# generate_instances_sync reads the backend's local cache either way.
SKIP_CONNECTED_WAIT = 0xFFFFFFFF

# ms. Coalesces bursts of view signals, as a server pull delivers one per object.
EMIT_DELAY = 150


def warn(message):
    print("calendar_events: " + message, file=sys.stderr, flush=True)


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


def sort_key(event):
    # All-day first, then by start. Ties fall back to the title for a stable order.
    return (0 if event["allDay"] else 1, event["start"], event["summary"])


class Calendars:
    def __init__(self, registry):
        self.registry = registry
        self.zone = ECal.util_get_system_timezone()
        self.year = 0
        # Source uid -> ECal.Client, and its view.
        self.clients = {}
        self.views = {}
        # Source uids with a connect in flight.
        self.opening = set()
        self.emit_timer = 0
        self.last_payload = None

        for signal in ("source-added", "source-enabled"):
            registry.connect(signal, lambda _r, source: self.open(source))
        for signal in ("source-removed", "source-disabled"):
            registry.connect(signal, lambda _r, source: self.close(source))
        # Name or colour edits. Registry reports each through source-changed.
        registry.connect("source-changed", lambda _r, _s: self.schedule_emit())

        for source in registry.list_enabled(EDataServer.SOURCE_EXTENSION_CALENDAR):
            self.open(source)

    def open(self, source):
        uid = source.get_uid()
        if (
            not source.has_extension(EDataServer.SOURCE_EXTENSION_CALENDAR)
            or not self.registry.check_enabled(source)
            or uid in self.clients
            or uid in self.opening
        ):
            return
        self.opening.add(uid)
        ECal.Client.connect(
            source,
            ECal.ClientSourceType.EVENTS,
            SKIP_CONNECTED_WAIT,
            None,
            self.on_connected,
            source,
        )

    def on_connected(self, _source_object, result, source):
        uid = source.get_uid()
        self.opening.discard(uid)
        try:
            client = ECal.Client.connect_finish(result)
        except Exception as error:
            warn("calendar %r did not open: %s" % (source.get_display_name(), error))
            return
        # Source disabled while the connect ran.
        if not self.registry.check_enabled(source):
            return
        client.set_default_timezone(self.zone)

        # View delivers edits made on the server or in another client.
        # No initial notification: the next emit reads the cache anyway.
        try:
            _ok, view = client.get_view_sync("#t", None)
            view.set_flags(ECal.ClientViewFlags.NONE)
            for signal in ("objects-added", "objects-modified", "objects-removed"):
                view.connect(signal, lambda *_args: self.schedule_emit())
            view.start()
            self.views[uid] = view
        except Exception as error:
            warn("calendar %r has no live view: %s" % (source.get_display_name(), error))

        self.clients[uid] = client
        self.schedule_emit()

    def close(self, source):
        uid = source.get_uid()
        view = self.views.pop(uid, None)
        if view is not None:
            view.stop()
        if self.clients.pop(uid, None) is not None:
            self.schedule_emit()

    def set_year(self, year):
        self.year = year
        self.schedule_emit()

    def refresh(self):
        """Pulls every open calendar, and has each account rediscover its calendars.

        Both calls return once the pull is scheduled.
        Changes arrive later through the views and the registry signals.
        """
        accounts = set()
        for client in self.clients.values():
            client.refresh(None, self.on_refreshed)
            account = self.registry.find_extension(
                client.get_source(), EDataServer.SOURCE_EXTENSION_COLLECTION
            )
            if account is not None:
                accounts.add(account.get_uid())
        for uid in accounts:
            self.registry.refresh_backend(uid, None, self.on_account_refreshed)

    def on_refreshed(self, client, result):
        try:
            client.refresh_finish(result)
        except Exception as error:
            warn(
                "calendar %r did not refresh: %s"
                % (client.get_source().get_display_name(), error)
            )

    def on_account_refreshed(self, registry, result):
        try:
            registry.refresh_backend_finish(result)
        except Exception as error:
            warn("account did not refresh: %s" % error)

    def schedule_emit(self):
        if self.emit_timer:
            GLib.source_remove(self.emit_timer)
        self.emit_timer = GLib.timeout_add(EMIT_DELAY, self.emit)

    def emit(self):
        self.emit_timer = 0
        if self.year == 0:
            return GLib.SOURCE_REMOVE

        days = {}
        calendars = {}
        for uid, client in self.clients.items():
            source = client.get_source()
            calendars[uid] = calendar_entry(source)
            self.read(client, uid, days)
        for events in days.values():
            events.sort(key=sort_key)

        payload = json.dumps({"year": self.year, "calendars": calendars, "days": days})
        if payload != self.last_payload:
            self.last_payload = payload
            print(payload, flush=True)
        return GLib.SOURCE_REMOVE

    def read(self, client, uid, days):
        """Adds one calendar's instances in the requested year to days."""
        year = self.year
        first_of_year = date(year, 1, 1)
        last_of_year = date(year, 12, 31)
        # Naive datetimes, so timestamp() reads them in the machine's zone.
        window_start = int(datetime(year, 1, 1).timestamp())
        window_end = int(datetime(year + 1, 1, 1).timestamp())

        def on_instance(icomp, start, end, *_rest):
            all_day = start.is_date()
            # Instances arrive in the event's own zone, UTC for a "Z" time.
            # Floating times keep their wall clock.
            if not all_day:
                start = start.convert_to_zone(self.zone)
                end = end.convert_to_zone(self.zone)
            event = {
                "summary": icomp.get_summary() or "",
                "allDay": all_day,
                "start": "" if all_day else clock(start),
                "end": "" if all_day else clock(end),
                "calendar": uid,
            }
            for day in covered_days(start, end, all_day, first_of_year, last_of_year):
                days.setdefault(day.isoformat(), []).append(event)
            return True

        try:
            client.generate_instances_sync(window_start, window_end, None, on_instance)
        except Exception as error:
            warn(
                "calendar %r did not read: %s"
                % (client.get_source().get_display_name(), error)
            )


def main():
    try:
        registry = EDataServer.SourceRegistry.new_sync(None)
    except Exception as error:
        warn("registry unavailable: %s" % error)
        return 1

    loop = GLib.MainLoop()
    calendars = Calendars(registry)
    commands = Gio.DataInputStream.new(GioUnix.InputStream.new(0, False))

    def on_line(stream, result):
        line, _length = stream.read_line_finish_utf8(result)
        # Shell gone.
        if line is None:
            loop.quit()
            return
        command = line.strip()
        if command == "refresh":
            calendars.refresh()
        elif command.isdigit():
            calendars.set_year(int(command))
        elif command:
            warn("unknown command %r" % command)
        stream.read_line_async(GLib.PRIORITY_DEFAULT, None, on_line)

    commands.read_line_async(GLib.PRIORITY_DEFAULT, None, on_line)
    loop.run()
    return 0


if __name__ == "__main__":
    sys.exit(main())

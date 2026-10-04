#!/usr/bin/env bash
# Opens GNOME Calendar on one day, with its new-event editor up.
# Arg: day month first, "10/15/2026".
# gnome-calendar parses --date with evolution-data-server's untranslated "%m/%d/%Y";
# German "15.10.2026" fails despite LC_TIME=de_DE.
# Unparsed date logs "Date … is invalid" and editor opens on today.
set -euo pipefail

# Starts service through D-Bus activation, as desktop entry does.
# Primary launched as `gnome-calendar --date` aborts building its first window
# (gcal_date_time_get_start_of_week assertion).
busctl --user call org.gnome.Calendar /org/gnome/Calendar org.freedesktop.DBus.Peer Ping

# Forwards to service, returns once window shows the day.
# Every run prints a g_time_zone_get_identifier CRITICAL.
gnome-calendar --date "$1" 2>/dev/null

# GtkApplication exports window actions at /org/gnome/Calendar/window/<id>.
# Id climbs per window service opened; highest belongs to open one.
win=$(busctl --user tree --list org.gnome.Calendar | grep -E '^/org/gnome/Calendar/window/[0-9]+$' | sort -t/ -k5 -n | tail -1)

# Ctrl+N action: all-day event on window's active date.
busctl --user call org.gnome.Calendar "$win" org.gtk.Actions Activate 'sava{sv}' new-event 0 0

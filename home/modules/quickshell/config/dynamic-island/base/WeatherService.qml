pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../menus/WeatherUtils.js" as WeatherUtils

// Weather for the calendar menu. Singleton: location + forecast are machine-global,
// the menu is per-screen. One geolocate, one forecast feed every Bar's calendar.
//
// Location resolves once per session from the public IP (ipapi.co), then the
// forecast comes from Open-Meteo. Both run through curl; QML parses the JSON.
// refresh() is the only entry point: the calendar calls it on open. No polling,
// no continuous surface, so no open/close refcount.
Singleton {
    id: root

    // ---- published state ----
    property bool located: false
    property real latitude: 0
    property real longitude: 0
    property string city: ""

    property bool ready: false        // forecast loaded at least once
    property bool failed: false       // last attempt failed, nothing to show
    property int currentTemp: 0
    property int currentCode: -1
    property bool currentIsDay: true
    property real currentHour: 12
    property var dayHours: []         // 24 entries: { hour, temp, code, isDay, base }

    // True while a calendar menu is open. Gates the scene animation and drives the
    // fetch. Set from the Bar's calendar HoverItem.
    property bool menuOpen: false
    function setMenuOpen(open) {
        root.menuOpen = open;
        if (open)
            root.refresh();
    }

    // Skip a refetch while the forecast is younger than this.
    readonly property int _freshMs: 600000    // 10 min
    property double _lastFetchMs: 0

    // Calendar-open entry point. Geolocate first run, then forecast; later opens
    // reuse a fresh forecast and only refetch once stale.
    function refresh() {
        if (!root.located) {
            if (!locateProc.running)
                locateProc.running = true;
            return;
        }
        if (root.ready && (Date.now() - root._lastFetchMs) < root._freshMs)
            return;
        root._fetchForecast();
    }

    function _fetchForecast() {
        if (forecastProc.running)
            return;
        forecastProc.command = ["curl", "-s", "--max-time", "8", "https://api.open-meteo.com/v1/forecast" + "?latitude=" + root.latitude + "&longitude=" + root.longitude + "&current=temperature_2m,weather_code,is_day" + "&hourly=temperature_2m,weather_code,is_day" + "&forecast_days=1&timezone=auto"];
        forecastProc.running = true;
    }

    Process {
        id: locateProc
        command: ["curl", "-s", "--max-time", "8", "https://ipapi.co/json/"]
        stdout: StdioCollector {
            id: locateOut
            onStreamFinished: {
                const r = WeatherUtils.parseLocation(locateOut.text);
                if (r.ok) {
                    root.latitude = r.lat;
                    root.longitude = r.lon;
                    root.city = r.city;
                    root.located = true;
                    root._fetchForecast();
                } else {
                    root.failed = true;
                }
            }
        }
    }

    Process {
        id: forecastProc
        stdout: StdioCollector {
            id: forecastOut
            onStreamFinished: {
                const r = WeatherUtils.parseForecast(forecastOut.text);
                if (r.ok) {
                    root.currentTemp = r.currentTemp;
                    root.currentCode = r.currentCode;
                    root.currentIsDay = r.currentIsDay;
                    root.currentHour = r.currentHour;
                    root.dayHours = r.day;
                    root.ready = true;
                    root.failed = false;
                    root._lastFetchMs = Date.now();
                } else if (!root.ready) {
                    root.failed = true;
                }
            }
        }
    }
}

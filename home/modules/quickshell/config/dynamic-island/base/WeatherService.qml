pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../menus/WeatherUtils.js" as WeatherUtils

// Weather for the calendar menu. Singleton: location + forecast are machine-global,
// the menu is per-screen. One geolocate, one forecast feed every Bar's calendar.
//
// Location resolves from the public IP and is cached on disk, so geolocation runs
// at most once per _locFreshMs, and a stale cache still covers a provider outage.
// Providers are tried in order (ipwho.is, then geojs) for robustness. The forecast
// comes from Open-Meteo (no key). Everything runs through curl; QML parses the JSON.
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
    property var dayHours: []          // 24 entries: { hour, temp, code, isDay, base }

    // True while a calendar menu is open. Drives the fetch. Set from the Bar.
    property bool menuOpen: false
    function setMenuOpen(open) {
        root.menuOpen = open;
        if (open)
            root.refresh();
    }

    readonly property int _freshMs: 600000       // forecast: refetch after 10 min
    readonly property int _locFreshMs: 21600000  // location: re-geolocate after 6 h
    property double _lastFetchMs: 0

    readonly property var _geoUrls: ["https://ipwho.is/", "https://get.geojs.io/v1/ip/geo.json"]
    property int _geoIdx: 0
    property bool _cacheTried: false
    property var _staleLoc: null       // last cached location, used if geolocation fails
    readonly property string _cachePath: (Quickshell.env("HOME") || "/tmp") + "/.cache/quickshell/weather-location"

    // Calendar-open entry point. Resolve location (cache, then providers) once, then
    // the forecast; later opens reuse a fresh forecast and only refetch once stale.
    function refresh() {
        if (!root.located) {
            root._resolveLocation();
            return;
        }
        if (root.ready && (Date.now() - root._lastFetchMs) < root._freshMs)
            return;
        root._fetchForecast();
    }

    function _resolveLocation() {
        if (!root._cacheTried) {
            if (!cacheReadProc.running)
                cacheReadProc.running = true;
            return;
        }
        root._geolocate(0);
    }
    function _useLocation(lat, lon, city) {
        root.latitude = lat;
        root.longitude = lon;
        root.city = city;
        root.located = true;
        root.failed = false;
        root._fetchForecast();
    }
    function _geolocate(idx) {
        root._geoIdx = idx;
        if (idx >= root._geoUrls.length) {
            if (root._staleLoc)
                root._useLocation(root._staleLoc.lat, root._staleLoc.lon, root._staleLoc.city);
            else
                root.failed = true;
            return;
        }
        if (locateProc.running)
            return;
        locateProc.command = ["curl", "-s", "--max-time", "8", root._geoUrls[idx]];
        locateProc.running = true;
    }

    function _fetchForecast() {
        if (forecastProc.running)
            return;
        forecastProc.command = ["curl", "-s", "--max-time", "8", "https://api.open-meteo.com/v1/forecast" + "?latitude=" + root.latitude + "&longitude=" + root.longitude + "&current=temperature_2m,weather_code,is_day" + "&hourly=temperature_2m,weather_code,is_day" + "&forecast_days=1&timezone=auto"];
        forecastProc.running = true;
    }

    function _shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    // ---- cached location ----
    // File holds "lat|lon|city|epochMs". Fresh -> use directly; stale -> keep as
    // fallback and geolocate; missing/garbage -> geolocate.
    Process {
        id: cacheReadProc
        command: ["cat", root._cachePath]
        stdout: StdioCollector {
            id: cacheOut
            onStreamFinished: {
                root._cacheTried = true;
                const parts = cacheOut.text.trim().split("|");
                if (parts.length >= 4) {
                    const lat = parseFloat(parts[0]), lon = parseFloat(parts[1]);
                    const ts = parseFloat(parts[3]);
                    if (isFinite(lat) && isFinite(lon)) {
                        root._staleLoc = { lat: lat, lon: lon, city: parts[2] };
                        if (isFinite(ts) && (Date.now() - ts) < root._locFreshMs) {
                            root._useLocation(lat, lon, parts[2]);
                            return;
                        }
                    }
                }
                root._geolocate(0);
            }
        }
    }
    Process { id: cacheWriteProc }
    function _writeCache(lat, lon, city) {
        const line = lat + "|" + lon + "|" + city + "|" + Date.now();
        const dir = root._cachePath.substring(0, root._cachePath.lastIndexOf("/"));
        cacheWriteProc.command = ["bash", "-c", "mkdir -p " + _shellQuote(dir) + " && printf '%s' " + _shellQuote(line) + " > " + _shellQuote(root._cachePath)];
        cacheWriteProc.running = true;
    }

    Process {
        id: locateProc
        stdout: StdioCollector {
            id: locateOut
            onStreamFinished: {
                const r = WeatherUtils.parseLocation(locateOut.text);
                if (r.ok) {
                    root._writeCache(r.lat, r.lon, r.city);
                    root._useLocation(r.lat, r.lon, r.city);
                } else {
                    root._geolocate(root._geoIdx + 1);   // try the next provider
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

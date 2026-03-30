// WallpaperAccent - Extracts a vibrant accent color from the current wallpaper
// using ImageMagick. Caches results per wallpaper in
// $HOME/.cache/quickshell/wallpaper-accents/ so subsequent loads are instant.
//
// A single bash process per resolve handles both cache lookup and extraction.
// A generation counter discards stale results when the wallpaper changes
// before the previous resolve finishes.

import QtQuick
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: root
    visible: false

    readonly property string _cacheDir: Quickshell.env("HOME") + "/.cache/quickshell/wallpaper-accents"

    // Re-extract when wallpaper changes
    property url _wallpaper: Globals.wallpaperPath
    on_WallpaperChanged: _resolve()

    Component.onCompleted: _resolve()

    // Generation counter — bumped on each _resolve(), checked in all handlers
    property int _generation: 0

    // Accumulate histogram entries for the current generation
    property var _candidates: []

    function _wallpaperFile() {
        return Globals.wallpaperPath.toString().replace("file://", "");
    }

    function _cacheFile() {
        const path = _wallpaperFile();
        const name = path.substring(path.lastIndexOf("/") + 1).replace(/\.[^.]+$/, "");
        return _cacheDir + "/" + name;
    }

    function _resolve() {
        _generation++;
        _candidates = [];

        const wallpaper = _wallpaperFile();
        const cache = _cacheFile();
        console.log("[WallpaperAccent] Resolving accent for:", wallpaper, "(gen " + _generation + ")");

        // Single process: check cache first, fall back to magick extraction.
        // Output is prefixed so QML can distinguish: "CACHED:#rrggbb" vs histogram lines.
        resolveProc.command = ["bash", "-c",
            "if [ -f '" + cache + "' ]; then " +
            "  echo \"CACHED:$(cat '" + cache + "')\"; " +
            "else " +
            "  magick '" + wallpaper + "' -resize 64x64! -colors 16 -depth 8 -format '%c' histogram:info: | sort -rn; " +
            "fi"
        ];
        resolveProc.running = true;
    }

    Process {
        id: resolveProc

        property int generation

        onRunningChanged: {
            if (running)
                generation = root._generation;
        }

        stdout: SplitParser {
            onRead: data => {
                if (resolveProc.generation !== root._generation) return;

                if (data.startsWith("CACHED:")) {
                    const color = data.substring(7).trim();
                    console.log("[WallpaperAccent] Cache hit:", color);
                    Globals.accentColor = color;
                } else {
                    root.parseLine(data);
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (generation !== root._generation) return;
            if (exitCode !== 0) {
                console.log("[WallpaperAccent] resolve failed with exit code", exitCode);
                return;
            }
            // If candidates were collected, this was an extraction (not a cache hit)
            if (root._candidates.length > 0)
                root.pickBestColor();
        }
    }

    Process {
        id: cacheSaveProc
    }

    function parseLine(line) {
        // Format: "  count: (R,G,B) #RRGGBB srgb(...)"
        const rgbMatch = line.match(/\((\d+),(\d+),(\d+)\)/);
        const countMatch = line.match(/^\s*(\d+):/);
        if (!rgbMatch || !countMatch)
            return;
        const count = parseInt(countMatch[1]);
        const r = parseInt(rgbMatch[1]) / 255;
        const g = parseInt(rgbMatch[2]) / 255;
        const b = parseInt(rgbMatch[3]) / 255;

        // Convert to HSL
        const max = Math.max(r, g, b);
        const min = Math.min(r, g, b);
        const l = (max + min) / 2;
        const d = max - min;

        if (d < 0.08)
            // skip grays
            return;
        if (l < 0.1 || l > 0.9)
            // skip near-black/white

            return;
        const s = d / (1 - Math.abs(2 * l - 1));
        if (s < 0.15)
            // skip desaturated

            return;
        let h;
        if (max === r)
            h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
        else if (max === g)
            h = ((b - r) / d + 2) / 6;
        else
            h = ((r - g) / d + 4) / 6;

        _candidates.push({
            count: count,
            h: h,
            s: s,
            l: l,
            weight: count * s * s
        });
    }

    function pickBestColor() {
        if (_candidates.length === 0) {
            console.log("[WallpaperAccent] No vibrant colors found, using fallback");
            Globals.accentColor = "#f2ef45";
            _candidates = [];
            return;
        }

        // Pick candidate with highest weight (count * saturation^2)
        let best = _candidates[0];
        for (let i = 1; i < _candidates.length; i++) {
            if (_candidates[i].weight > best.weight) {
                best = _candidates[i];
            }
        }

        // Boost saturation and fix lightness for accent use
        const accentSat = Math.min(0.75, best.s * 1.3);
        const accentLight = 0.65;
        const color = hslToHex(best.h, accentSat, accentLight);

        console.log("[WallpaperAccent] Extracted color:", color);
        Globals.accentColor = color;
        _candidates = [];

        // Save to cache
        const cache = _cacheFile();
        cacheSaveProc.command = ["bash", "-c", "mkdir -p '" + _cacheDir + "' && echo '" + color + "' > '" + cache + "'"];
        cacheSaveProc.running = true;
    }

    function hslToHex(h, s, l) {
        const c = (1 - Math.abs(2 * l - 1)) * s;
        const x = c * (1 - Math.abs((h * 6) % 2 - 1));
        const m = l - c / 2;

        let r, g, b;
        const sector = Math.floor(h * 6) % 6;
        switch (sector) {
        case 0:
            r = c;
            g = x;
            b = 0;
            break;
        case 1:
            r = x;
            g = c;
            b = 0;
            break;
        case 2:
            r = 0;
            g = c;
            b = x;
            break;
        case 3:
            r = 0;
            g = x;
            b = c;
            break;
        case 4:
            r = x;
            g = 0;
            b = c;
            break;
        default:
            r = c;
            g = 0;
            b = x;
            break;
        }

        const toHex = v => {
            const hex = Math.round((v + m) * 255).toString(16);
            return hex.length < 2 ? "0" + hex : hex;
        };

        return "#" + toHex(r) + toHex(g) + toHex(b);
    }
}

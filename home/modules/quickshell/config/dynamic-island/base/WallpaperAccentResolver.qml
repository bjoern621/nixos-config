// Resolves a wallpaper's accent color via ImageMagick.
// Caches per wallpaper under $HOME/.cache/quickshell/wallpaper-accents/,
// so later loads skip magick.

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false

    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/quickshell/wallpaper-accents"
    readonly property bool busy: cacheCheckProc.running || extractProc.running

    // Empty color when magick failed.
    signal finished(string path, string color)

    function cacheFile(path) {
        const name = path.substring(path.lastIndexOf("/") + 1).replace(/\.[^.]+$/, "");
        return cacheDir + "/" + name;
    }

    function shellEscape(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'";
    }

    function saveToCache(value, path) {
        cacheSaveProc.command = ["bash", "-c", "mkdir -p " + shellEscape(cacheDir) + " && echo " + shellEscape(value) + " > " + shellEscape(path)];
        cacheSaveProc.running = true;
    }

    // Ignored while busy: Process.running ignores a write of true mid-run.
    function resolve(path) {
        if (busy)
            return;
        // Target captured per run, carried through extraction.
        cacheCheckProc.target = path;
        cacheCheckProc.cachePath = cacheFile(path);
        cacheCheckProc.cached = "";
        cacheCheckProc.command = ["bash", "-c", "cat " + shellEscape(cacheCheckProc.cachePath) + " 2>/dev/null || echo 'MISS'"];
        cacheCheckProc.running = true;
    }

    Process {
        id: cacheCheckProc

        property string target: ""
        property string cachePath: ""
        property string cached: ""

        stdout: SplitParser {
            onRead: data => {
                cacheCheckProc.cached = data.trim();
            }
        }

        // Not in onRead: this process still runs there, so a caller queueing its next
        // wallpaper from finished would hit busy.
        onExited: {
            if (cached === "MISS") {
                extractProc.target = target;
                extractProc.cachePath = cachePath;
                extractProc.running = true;
            } else {
                root.finished(target, cached);
            }
        }
    }

    Process {
        id: extractProc

        property var candidates: []
        // Wallpaper this run was requested for.
        // Binding the command to the live wallpaper runs magick against a newer selection,
        // caching its colour under the older one's name.
        // Cache never self-corrects.
        property string target: ""
        property string cachePath: ""

        command: ["bash", "-c", "magick " + root.shellEscape(extractProc.target) + " -resize 64x64! -colors 16 -depth 8 -format '%c' histogram:info: | sort -rn"]

        onRunningChanged: {
            if (running)
                candidates = [];
        }

        stdout: SplitParser {
            onRead: data => {
                extractProc.parseHistogramLine(data);
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("[WallpaperAccent] magick failed (exit " + exitCode + ")");
                root.finished(target, "");
                return;
            }

            if (candidates.length === 0) {
                const fallback = Globals.defaultAccentColor.toString();

                root.saveToCache(fallback, cachePath);
                root.finished(target, fallback);
                return;
            }

            let best = candidates[0];
            for (let i = 1; i < candidates.length; i++) {
                if (candidates[i].weight > best.weight)
                    best = candidates[i];
            }

            const accentSat = Math.min(0.75, best.s * 1.3);
            const accentLight = 0.65;
            const color = hslToHex(best.h, accentSat, accentLight);

            root.saveToCache(color, cachePath);
            root.finished(target, color);
        }

        function parseHistogramLine(line) {
            // Format: "  count: (R,G,B) #RRGGBB srgb(...)"
            const rgbMatch = line.match(/\((\d+),(\d+),(\d+)\)/);
            const countMatch = line.match(/^\s*(\d+):/);
            if (!rgbMatch || !countMatch)
                return;

            const count = parseInt(countMatch[1]);
            const r = parseInt(rgbMatch[1]) / 255;
            const g = parseInt(rgbMatch[2]) / 255;
            const b = parseInt(rgbMatch[3]) / 255;

            const max = Math.max(r, g, b);
            const min = Math.min(r, g, b);
            const l = (max + min) / 2;
            const d = max - min;

            if (d < 0.08)
                return; // too gray
            if (l < 0.1 || l > 0.9)
                return; // too dark/light
            const s = d / (1 - Math.abs(2 * l - 1));
            if (s < 0.15)
                return; // too desaturated

            let h;
            if (max === r)
                h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
            else if (max === g)
                h = ((b - r) / d + 2) / 6;
            else
                h = ((r - g) / d + 4) / 6;

            candidates.push({
                count: count,
                h: h,
                s: s,
                l: l,
                weight: count * s * s
            });
        }
    }

    Process {
        id: cacheSaveProc
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

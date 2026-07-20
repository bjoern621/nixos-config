import QtQuick
import Quickshell.Io

// Dominant-accent extractor.
// Runs an ImageMagick histogram over a local image, keeps the most saturated
// weighted color, emits it via resolved(). Caller owns source I/O (download,
// caching) and re-arms on busy.
QtObject {
    id: root

    // "#rrggbb" for a surviving color, "" when none clears the saturation gate.
    signal resolved(string colorHex)
    // magick exited nonzero.
    signal failed

    // Saturation ceiling and fixed lightness of the emitted color.
    property real saturationCap: 0.75
    property real lightness: 0.65

    readonly property bool busy: proc.running

    // path: local file magick can read. No-op returning false while busy.
    function extract(path) {
        if (proc.running)
            return false;
        proc.candidates = [];
        proc.command = ["bash", "-c", "magick " + root._shellEscape(path) + " -resize 64x64! -colors 16 -depth 8 -format '%c' histogram:info: | sort -rn"];
        proc.running = true;
        return true;
    }

    function _shellEscape(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'";
    }

    property Process _proc: Process {
        id: proc

        property var candidates: []

        stdout: SplitParser {
            onRead: data => root._parseHistogramLine(data)
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.failed();
                return;
            }
            if (candidates.length === 0) {
                root.resolved("");
                return;
            }

            let best = candidates[0];
            for (let i = 1; i < candidates.length; i++) {
                if (candidates[i].weight > best.weight)
                    best = candidates[i];
            }

            const accentSat = Math.min(root.saturationCap, best.s * 1.3);
            root.resolved(root._hslToHex(best.h, accentSat, root.lightness));
        }
    }

    function _parseHistogramLine(line) {
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

        proc.candidates.push({
            count: count,
            h: h,
            s: s,
            l: l,
            weight: count * s * s
        });
    }

    function _hslToHex(h, s, l) {
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

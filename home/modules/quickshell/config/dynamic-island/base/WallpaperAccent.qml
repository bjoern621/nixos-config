import QtQuick
import Quickshell
import "../"

QtObject {
    id: root

    readonly property int sampleSize: 64

    property var hiddenWindow: Window {
        width: root.sampleSize
        height: root.sampleSize
        visible: true
        x: -1000
        y: -1000
        color: "transparent"
        flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnBottomHint

        Canvas {
            id: canvas
            width: root.sampleSize
            height: root.sampleSize
            visible: true

            property string imagePath: Globals.wallpaperPath.toString().replace("file://", "")

            Component.onCompleted: {
                loadImage(imagePath)
            }

            onImageLoaded: {
                requestPaint()
            }

        onPaint: {
            const ctx = getContext("2d")
            const imagePath = Globals.wallpaperPath.toString().replace("file://", "")
            ctx.drawImage(imagePath, 0, 0, width, height)
            const imageData = ctx.getImageData(0, 0, width, height)
            const pixels = imageData.data

            const color = extractVibrantColor(pixels, width, height)
            console.log("[WallpaperAccent] Extracted color:", color)
            Globals.accentColor = color
        }
    }
    }

    function extractVibrantColor(pixels, w, h) {
        // Bucket hues into 12 segments of 30 degrees each
        const bucketCount = 12
        const buckets = []
        for (let i = 0; i < bucketCount; i++) {
            buckets.push({ count: 0, hueSum: 0, satSum: 0, lightSum: 0 })
        }

        const total = w * h
        for (let i = 0; i < total; i++) {
            const idx = i * 4
            const r = pixels[idx] / 255
            const g = pixels[idx + 1] / 255
            const b = pixels[idx + 2] / 255

            const max = Math.max(r, g, b)
            const min = Math.min(r, g, b)
            const l = (max + min) / 2
            const d = max - min

            if (d < 0.08) continue // skip grays
            if (l < 0.1 || l > 0.9) continue // skip near-black/white

            const s = d / (1 - Math.abs(2 * l - 1))
            if (s < 0.15) continue // skip desaturated

            let h
            if (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6
            else if (max === g) h = ((b - r) / d + 2) / 6
            else h = ((r - g) / d + 4) / 6

            const bi = Math.min(Math.floor(h * bucketCount), bucketCount - 1)
            // Weight by saturation so vivid pixels win
            const weight = s * s
            buckets[bi].count += weight
            buckets[bi].hueSum += h * weight
            buckets[bi].satSum += s * weight
            buckets[bi].lightSum += l * weight
        }

        // Find the most populated bucket
        let best = 0
        for (let i = 1; i < bucketCount; i++) {
            if (buckets[i].count > buckets[best].count) best = i
        }

        const b = buckets[best]
        if (b.count === 0) {
            return "#f2ef45" // fallback
        }

        const avgHue = b.hueSum / b.count
        // Boost saturation and pick a pleasant lightness for accent use
        const accentSat = Math.min(0.75, (b.satSum / b.count) * 1.3)
        const accentLight = 0.65

        return hslToHex(avgHue, accentSat, accentLight)
    }

    function hslToHex(h, s, l) {
        const c = (1 - Math.abs(2 * l - 1)) * s
        const x = c * (1 - Math.abs((h * 6) % 2 - 1))
        const m = l - c / 2

        let r, g, b
        const sector = Math.floor(h * 6) % 6
        switch (sector) {
            case 0: r = c; g = x; b = 0; break
            case 1: r = x; g = c; b = 0; break
            case 2: r = 0; g = c; b = x; break
            case 3: r = 0; g = x; b = c; break
            case 4: r = x; g = 0; b = c; break
            default: r = c; g = 0; b = x; break
        }

        const toHex = v => {
            const hex = Math.round((v + m) * 255).toString(16)
            return hex.length < 2 ? "0" + hex : hex
        }

        return "#" + toHex(r) + toHex(g) + toHex(b)
    }
}

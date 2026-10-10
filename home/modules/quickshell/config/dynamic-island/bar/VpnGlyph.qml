import QtQuick
import "../base"

// Tunnel-active glyph: key with a ring head, Android's VPN status icon. Drawn
// rather than an SVG so it recolors with the theme, matching NetworkGlyph.
Canvas {
    id: root

    property color color: Colors.accentColor

    onColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        const w = width;
        const h = height;
        ctx.reset();
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.strokeStyle = color;
        ctx.lineWidth = Math.max(1.4, w * 0.14);

        // Ring head on the left.
        ctx.beginPath();
        ctx.arc(w * 0.28, h * 0.5, w * 0.19, 0, Math.PI * 2);
        ctx.stroke();

        // Shaft to the right edge.
        ctx.beginPath();
        ctx.moveTo(w * 0.47, h * 0.5);
        ctx.lineTo(w * 0.92, h * 0.5);
        ctx.stroke();

        // Two teeth hanging off the shaft.
        ctx.beginPath();
        ctx.moveTo(w * 0.74, h * 0.5);
        ctx.lineTo(w * 0.74, h * 0.72);
        ctx.moveTo(w * 0.90, h * 0.5);
        ctx.lineTo(w * 0.90, h * 0.68);
        ctx.stroke();
    }
}

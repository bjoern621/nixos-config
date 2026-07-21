import QtQuick
import "../base"

// VPN-active glyph: filled shield with a check. Drawn rather than an SVG so it
// recolors with the theme, matching NetworkGlyph's shape.
Canvas {
    id: root

    property color color: Colors.accentColor
    property color markColor: Colors.pillBackground

    onColorChanged: requestPaint()
    onMarkColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        const w = width;
        const h = height;
        ctx.reset();
        ctx.lineCap = "round";
        ctx.lineJoin = "round";

        // Shield: flat top, sides taper to a bottom point.
        ctx.beginPath();
        ctx.moveTo(w * 0.14, h * 0.16);
        ctx.lineTo(w * 0.86, h * 0.16);
        ctx.lineTo(w * 0.86, h * 0.54);
        ctx.quadraticCurveTo(w * 0.86, h * 0.80, w * 0.5, h * 0.94);
        ctx.quadraticCurveTo(w * 0.14, h * 0.80, w * 0.14, h * 0.54);
        ctx.closePath();
        ctx.fillStyle = color;
        ctx.fill();

        // Check cut into the shield.
        ctx.strokeStyle = markColor;
        ctx.lineWidth = Math.max(1.4, w * 0.12);
        ctx.beginPath();
        ctx.moveTo(w * 0.32, h * 0.50);
        ctx.lineTo(w * 0.44, h * 0.63);
        ctx.lineTo(w * 0.70, h * 0.36);
        ctx.stroke();
    }
}

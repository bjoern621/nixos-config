import QtQuick
import "../base"

// Canvas glyph for the three-way radio toggle: wifi (on), crossed wifi (off),
// airplane silhouette (airplane). Drawn, not SVG, so it recolors with the theme
// and matches the bar's NetworkGlyph line weight.
Canvas {
    id: root

    property string mode: "on"   // off | on | airplane
    property color color: Colors.textColor

    onModeChanged: requestPaint()
    onColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        if (mode === "airplane")
            _paintAirplane(ctx, width, height);
        else
            _paintWifi(ctx, width, height, mode === "off");
    }

    function _paintWifi(ctx, w, h, slashed) {
        const cx = w / 2;
        const cy = h * 0.72;
        const lw = Math.max(1.4, w * 0.09);
        const radii = [w * 0.17, w * 0.31, w * 0.45];

        ctx.lineWidth = lw;
        ctx.strokeStyle = color;
        for (let i = 0; i < 3; i++) {
            ctx.beginPath();
            ctx.arc(cx, cy, radii[i], 1.25 * Math.PI, 1.75 * Math.PI);
            ctx.stroke();
        }
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.arc(cx, cy, Math.max(1.2, w * 0.06), 0, 2 * Math.PI);
        ctx.fill();

        // Same-color diagonal, no gap: reads as a crossed-out wifi at this size.
        if (slashed) {
            ctx.lineWidth = Math.max(1.4, w * 0.085);
            ctx.beginPath();
            ctx.moveTo(w * 0.2, h * 0.16);
            ctx.lineTo(w * 0.8, h * 0.82);
            ctx.stroke();
        }
    }

    // Material airplanemode_active path, 24x24 viewBox, nose up. Filled.
    function _paintAirplane(ctx, w, h) {
        const s = Math.min(w, h) / 24;
        const ox = (w - 24 * s) / 2;
        const oy = (h - 24 * s) / 2;
        const X = x => ox + x * s;
        const Y = y => oy + y * s;

        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.moveTo(X(21), Y(16));
        ctx.lineTo(X(21), Y(14));
        ctx.lineTo(X(13), Y(9));
        ctx.lineTo(X(13), Y(3.5));
        ctx.quadraticCurveTo(X(13), Y(2), X(11.5), Y(2));
        ctx.quadraticCurveTo(X(10), Y(2), X(10), Y(3.5));
        ctx.lineTo(X(10), Y(9));
        ctx.lineTo(X(2), Y(14));
        ctx.lineTo(X(2), Y(16));
        ctx.lineTo(X(10), Y(13.5));
        ctx.lineTo(X(10), Y(19));
        ctx.lineTo(X(8), Y(20.5));
        ctx.lineTo(X(8), Y(22));
        ctx.lineTo(X(11.5), Y(21));
        ctx.lineTo(X(15), Y(22));
        ctx.lineTo(X(15), Y(20.5));
        ctx.lineTo(X(13), Y(19));
        ctx.lineTo(X(13), Y(13.5));
        ctx.closePath();
        ctx.fill();
    }
}

import QtQuick
import "../base"

// Canvas network symbol: wifi arcs (partial by level), ethernet jack, or a
// slashed radio-off state. Drawn rather than an SVG so it recolors with the
// theme and shows signal strength in one glyph.
Canvas {
    id: root

    property string mode: "wifi"   // wifi | ethernet | disconnected | wifi-off
    property int level: 3          // 0-3, wifi only
    property color color: Colors.textColor
    property color mutedColor: Qt.rgba(Colors.textColor.r, Colors.textColor.g, Colors.textColor.b, 0.25)

    onModeChanged: requestPaint()
    onLevelChanged: requestPaint()
    onColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        const w = width;
        const h = height;
        ctx.reset();
        ctx.lineCap = "round";
        ctx.lineJoin = "round";

        if (mode === "ethernet") {
            _paintEthernet(ctx, w, h);
            return;
        }

        _paintWifi(ctx, w, h);

        if (mode === "disconnected" || mode === "wifi-off")
            _paintSlash(ctx, w, h);
    }

    function _paintWifi(ctx, w, h) {
        const cx = w / 2;
        const cy = h * 0.80;
        const lw = Math.max(1.5, w * 0.09);
        const dim = (mode === "disconnected" || mode === "wifi-off");
        const radii = [w * 0.18, w * 0.33, w * 0.48];

        ctx.lineWidth = lw;
        for (let i = 0; i < 3; i++) {
            const lit = !dim && (level >= i + 1);
            ctx.strokeStyle = lit ? color : mutedColor;
            ctx.beginPath();
            ctx.arc(cx, cy, radii[i], 1.25 * Math.PI, 1.75 * Math.PI);
            ctx.stroke();
        }

        ctx.fillStyle = dim ? mutedColor : color;
        ctx.beginPath();
        ctx.arc(cx, cy, Math.max(1.3, w * 0.065), 0, 2 * Math.PI);
        ctx.fill();
    }

    function _paintEthernet(ctx, w, h) {
        ctx.strokeStyle = color;
        ctx.fillStyle = color;
        ctx.lineWidth = Math.max(1.4, w * 0.08);

        // Connector body.
        const bx = w * 0.26, by = h * 0.30, bw = w * 0.48, bh = h * 0.34;
        _roundRect(ctx, bx, by, bw, bh, w * 0.06);
        ctx.stroke();

        // Cable stub up from the body.
        ctx.beginPath();
        ctx.moveTo(w * 0.5, by);
        ctx.lineTo(w * 0.5, h * 0.16);
        ctx.stroke();

        // Two contact pins below.
        ctx.beginPath();
        ctx.moveTo(w * 0.4, by + bh);
        ctx.lineTo(w * 0.4, by + bh + h * 0.12);
        ctx.moveTo(w * 0.6, by + bh);
        ctx.lineTo(w * 0.6, by + bh + h * 0.12);
        ctx.stroke();
    }

    function _paintSlash(ctx, w, h) {
        ctx.lineWidth = Math.max(1.6, w * 0.1);
        // Paper-colored underlay so the slash reads over the arcs.
        ctx.strokeStyle = Colors.pillBackground;
        ctx.beginPath();
        ctx.moveTo(w * 0.16, h * 0.16);
        ctx.lineTo(w * 0.84, h * 0.84);
        ctx.stroke();

        ctx.lineWidth = Math.max(1.4, w * 0.075);
        ctx.strokeStyle = color;
        ctx.beginPath();
        ctx.moveTo(w * 0.19, h * 0.19);
        ctx.lineTo(w * 0.81, h * 0.81);
        ctx.stroke();
    }

    function _roundRect(ctx, x, y, rw, rh, r) {
        ctx.beginPath();
        ctx.moveTo(x + r, y);
        ctx.arcTo(x + rw, y, x + rw, y + rh, r);
        ctx.arcTo(x + rw, y + rh, x, y + rh, r);
        ctx.arcTo(x, y + rh, x, y, r);
        ctx.arcTo(x, y, x + rw, y, r);
        ctx.closePath();
    }
}

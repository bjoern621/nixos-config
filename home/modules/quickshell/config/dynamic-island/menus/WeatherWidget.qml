import QtQuick
import "../"
import "../base"
import "WeatherUtils.js" as WeatherUtils

// Calendar weather panel: a stylized sky scene (SkyScene) over a rolling 24h
// timeline ribbon running from the current hour into tomorrow. The scene reflects
// "now" by default; dragging the ribbon scrubs it. Animation runs only while the
// calendar menu is open.
// Caller sets width (calendar grid width); height is reserved so the card does
// not jump between loading and ready.
Item {
    id: root

    readonly property var svc: WeatherService

    // True only while THIS screen's calendar popup is open. Per-screen, so a calendar
    // on one monitor never animates the (hidden) scenes on the others.
    property bool active: false

    readonly property int sceneHeight: Math.max(150, Math.min(220, Math.round(width * 0.26)))
    readonly property int ribbonHeight: 30
    readonly property int axisHeight: 14
    implicitHeight: sceneHeight + Spacing.spacing8 + ribbonHeight + Spacing.spacing4 + axisHeight

    // Live wall-clock hour, used to place "now" within the rolling window.
    readonly property real liveHour: {
        const d = Clock.date;
        return d.getHours() + d.getMinutes() / 60;
    }
    // Day-of-year (1..365) for the scene's seasonal sun height and hue.
    readonly property int dayOfYear: {
        const d = Clock.date;
        const start = new Date(d.getFullYear(), 0, 0);
        return Math.round((d.getTime() - start.getTime()) / 86400000);
    }
    // Moon phase 0..1 (0/1 new, 0.5 full) from a known new moon, for the night scene.
    readonly property real moonPhase: {
        const ref = Date.UTC(2000, 0, 6, 18, 14, 0);
        const syn = 29.530588853 * 86400000;
        let p = ((Clock.date.getTime() - ref) % syn) / syn;
        return p < 0 ? p + 1 : p;
    }

    // The ribbon is a 24h window from the current hour; svc.windowStartHour is the
    // clock hour of cell 0. Position pos in [0,1] runs now..now+24h. Scrubbing
    // overrides "now" until the menu reopens.
    property bool scrubbing: false
    property real scrubPos: 0
    readonly property real livePos: {
        let p = (root.liveHour - root.svc.windowStartHour) / 24;
        if (p < 0) p += 1;
        return Math.max(0, Math.min(1, p));
    }
    readonly property real displayPos: scrubbing ? scrubPos : livePos
    // Wall-clock hour (0..24) at a window position.
    function _posClock(pos) {
        let h = (root.svc.windowStartHour + pos * 24) % 24;
        return h < 0 ? h + 24 : h;
    }
    readonly property real sceneHour: _posClock(displayPos)

    // Menu close clears a scrub so the next open starts live on "now".
    onActiveChanged: if (!active) scrubbing = false

    // Window cell at position pos (0..1).
    function _cellAt(pos) {
        const a = root.svc.dayHours;
        if (!a || !a.length)
            return null;
        return a[Math.max(0, Math.min(23, Math.floor(pos * 24)))];
    }
    function _tempAt(pos) {
        const a = root.svc.dayHours;
        if (!a || !a.length)
            return root.svc.currentTemp;
        const x = Math.max(0, Math.min(23.999, pos * 24));
        const i = Math.floor(x), f = x - i, j = Math.min(23, i + 1);
        const ei = a[i], ej = a[j];
        if (!ei)
            return root.svc.currentTemp;
        if (!ej)
            return ei.temp;
        return ei.temp + (ej.temp - ei.temp) * f;
    }

    // Fractional hour to "HH:MM". Clamps to the 0..24 range.
    function _fmtHour(h) {
        const total = Math.round(Math.max(0, Math.min(24, h)) * 60);
        const hh = Math.floor(total / 60), mm = total % 60;
        return (hh < 10 ? "0" + hh : hh) + ":" + (mm < 10 ? "0" + mm : mm);
    }

    readonly property var _cur: _cellAt(displayPos)
    readonly property string _base: _cur ? _cur.base : "clear"

    // ---- placeholder until a forecast lands ----
    Text {
        anchors.centerIn: parent
        visible: !root.svc.ready
        text: root.svc.failed ? "Wetter nicht verfügbar" : "Wetter wird geladen …"
        font { family: Typography.fontFamily; pixelSize: Typography.fontSize12; weight: Font.Normal }
        color: Colors.textColorMuted
    }

    // ---- scene ----
    Rectangle {
        id: sceneFrame
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.sceneHeight
        visible: root.svc.ready
        radius: Shape.cardRadius
        color: "#0b1020"
        border.width: Shape.borderWidth
        border.color: Colors.pillBorder
        clip: true

        SkyScene {
            anchors.fill: parent
            anchors.margins: sceneFrame.border.width
            hour: root.sceneHour
            condition: root._base
            temp: root._tempAt(root.displayPos)
            sunrise: root.svc.sunriseHour
            sunset: root.svc.sunsetHour
            latitude: root.svc.latitude
            dayOfYear: root.dayOfYear
            cloud: root._cur ? root._cur.cloud : 0
            wind: root._cur ? root._cur.wind : 0
            windDir: root._cur ? root._cur.windDir : 0
            precip: root._cur ? root._cur.precip : 0
            snow: root._cur ? root._cur.snow : 0
            moonPhase: root.moonPhase
            animating: root.active && root.svc.ready
        }

        // Current temperature. No chrome; ink outline keeps it legible over any sky.
        Text {
            x: Spacing.spacing12
            y: Spacing.spacing8
            text: Math.round(root._tempAt(root.displayPos)) + "°"
            font { family: Typography.fontFamily; pixelSize: Typography.fontSize32; weight: Typography.weightHeavy }
            color: "white"
            style: Text.Outline
            styleColor: "#111111"
        }

        // Detected region. IP geolocation resolves the place the forecast and the
        // scene's daylight describe; naming it makes a wrong sunset traceable to a
        // wrong location rather than a scene bug.
        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: Spacing.spacing12
            anchors.topMargin: Spacing.spacing8
            width: Math.min(implicitWidth, parent.width * 0.55)
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            visible: root.svc.city.length > 0
            text: root.svc.city
            font { family: Typography.fontFamily; pixelSize: Typography.fontSize14; weight: Typography.weightBold }
            color: "white"
            style: Text.Outline
            styleColor: "#111111"
        }

        // Sunrise/sunset the forecast reports for that place. The scene's sun arc is
        // warped onto these, so the readout doubles as a check against a known source.
        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: Spacing.spacing12
            anchors.bottomMargin: Spacing.spacing8
            visible: root.svc.ready
            text: "↑ " + root._fmtHour(root.svc.sunriseHour) + "   ↓ " + root._fmtHour(root.svc.sunsetHour)
            font { family: Typography.fontFamily; pixelSize: Typography.fontSize12; weight: Typography.weightBold }
            color: "white"
            style: Text.Outline
            styleColor: "#111111"
        }
    }

    // ---- ribbon timeline ----
    Rectangle {
        id: ribbon
        anchors.top: sceneFrame.bottom
        anchors.topMargin: Spacing.spacing8
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.ribbonHeight
        visible: root.svc.ready
        radius: Shape.cardRadius
        color: "transparent"
        // ink frame drawn by this rect; band inset by borderWidth sits inside it.
        border.width: Shape.borderWidth
        border.color: Colors.pillBorder
        clip: true

        // color band + curve, inset inside the ink frame so the border crops it.
        // margins = borderWidth keeps the band off the frame; layer.enabled
        // rounds the band to the frame's inner radius (outer minus border).
        Rectangle {
            anchors.fill: parent
            anchors.margins: ribbon.border.width
            radius: ribbon.radius - ribbon.border.width
            color: "transparent"
            clip: true
            layer.enabled: true

            // Color band as one horizontal gradient, a stop per hour at its floating-point
            // position. Day/night twilight and condition changes blend across the hour
            // instead of stepping between 24 flat blocks. Depends only on the day's
            // forecast and sun times, not the scrub hour, so it repaints rarely.
            Canvas {
                id: band
                anchors.fill: parent
                onPaint: {
                    const a = root.svc.dayHours;
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    if (!a || !a.length)
                        return;
                    const sr = root.svc.sunriseHour, ss = root.svc.sunsetHour;
                    // Each present cell -> {window position, RGB from its condition and its
                    // own clock-hour dayness}. Dayness reads the cell's clock hour, not its
                    // window index, so day/night lands wherever it falls across the window.
                    const stops = [];
                    for (let i = 0; i < 24; i++) {
                        if (!a[i])
                            continue;
                        const dn = WeatherUtils.daynessAt(a[i].hour + 0.5, sr, ss);
                        stops.push({ pos: (i + 0.5) / 24, rgb: WeatherUtils.conditionRGB(a[i].base, dn) });
                    }
                    if (!stops.length)
                        return;
                    // Densify each hour transition with OKLab-interpolated sub-stops, so Qt's
                    // linear-RGB fill tracks the perceptual path and hues stay vivid mid-blend.
                    // Stops go strictly left-to-right; edge clamps at 0 and 1 fill the corners.
                    const grad = ctx.createLinearGradient(0, 0, width, 0);
                    const SUB = 4;
                    grad.addColorStop(0, WeatherUtils.rgbHex(stops[0].rgb));
                    for (let s = 0; s < stops.length; s++) {
                        grad.addColorStop(stops[s].pos, WeatherUtils.rgbHex(stops[s].rgb));
                        if (s + 1 < stops.length) {
                            const A = stops[s], B = stops[s + 1];
                            for (let t = 1; t < SUB; t++) {
                                const f = t / SUB;
                                grad.addColorStop(A.pos + (B.pos - A.pos) * f, WeatherUtils.rgbHex(WeatherUtils.oklabMix(A.rgb, B.rgb, f)));
                            }
                        }
                    }
                    grad.addColorStop(1, WeatherUtils.rgbHex(stops[stops.length - 1].rgb));
                    ctx.fillStyle = grad;
                    ctx.fillRect(0, 0, width, height);
                }
                Connections {
                    target: root.svc
                    function onDayHoursChanged() { band.requestPaint(); }
                    function onSunriseHourChanged() { band.requestPaint(); }
                    function onSunsetHourChanged() { band.requestPaint(); }
                }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }

            // temperature curve over the band
            Canvas {
                id: curve
                anchors.fill: parent
                onPaint: {
                    const a = root.svc.dayHours;
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    if (!a || a.length < 2)
                        return;
                    let tmin = 999, tmax = -999;
                    for (let k = 0; k < a.length; k++) {
                        if (!a[k]) continue;
                        tmin = Math.min(tmin, a[k].temp);
                        tmax = Math.max(tmax, a[k].temp);
                    }
                    if (tmax - tmin < 6) { tmin -= 3; tmax += 3; }
                    const pad = 5;
                    const pts = [];
                    // Track day extremes for their temp markers. peak = warmest (top
                    // of curve), low = coldest. .t is actual temp; x/y use scaled tmin/tmax.
                    let peak = null, low = null;
                    for (let k = 0; k < a.length; k++) {
                        if (!a[k]) continue;
                        const x = (k + 0.5) / 24 * width;
                        const y = height - pad - (a[k].temp - tmin) / (tmax - tmin) * (height - 2 * pad);
                        pts.push([x, y]);
                        if (!peak || a[k].temp > peak.t) peak = { x, y, t: a[k].temp };
                        if (!low || a[k].temp < low.t) low = { x, y, t: a[k].temp };
                    }
                    function trace() {
                        ctx.beginPath();
                        for (let k = 0; k < pts.length; k++)
                            k === 0 ? ctx.moveTo(pts[k][0], pts[k][1]) : ctx.lineTo(pts[k][0], pts[k][1]);
                        ctx.stroke();
                    }
                    ctx.lineJoin = "round"; ctx.lineCap = "round";
                    ctx.strokeStyle = "rgba(255,253,245,0.85)"; ctx.lineWidth = 4; trace();
                    ctx.strokeStyle = "rgba(20,20,20,0.9)"; ctx.lineWidth = 1.8; trace();

                    // Extreme markers: dot + outlined temp. dir=+1 puts the label
                    // below its point (peak sits near the top), dir=-1 above (low near bottom).
                    function extreme(p, dir) {
                        if (!p) return;
                        const label = Math.round(p.t) + "°";
                        ctx.textAlign = "center"; ctx.textBaseline = "middle";
                        ctx.font = 'bold ' + Typography.fontSize12 + 'px "' + Typography.fontFamily + '"';
                        const halfW = ctx.measureText(label).width / 2 + 2;
                        const lx = Math.max(halfW, Math.min(width - halfW, p.x));
                        const ly = Math.max(8, Math.min(height - 8, p.y + dir * 11));
                        ctx.beginPath(); ctx.arc(p.x, p.y, 2.5, 0, Math.PI * 2);
                        ctx.fillStyle = "rgba(255,253,245,0.95)"; ctx.fill();
                        ctx.lineWidth = 1.5; ctx.strokeStyle = "rgba(20,20,20,0.9)"; ctx.stroke();
                        ctx.lineWidth = 3; ctx.strokeStyle = "rgba(20,20,20,0.9)"; ctx.strokeText(label, lx, ly);
                        ctx.fillStyle = "rgba(255,253,245,0.98)"; ctx.fillText(label, lx, ly);
                    }
                    extreme(peak, 1);
                    extreme(low, -1);
                }
                Connections {
                    target: root.svc
                    function onDayHoursChanged() { curve.requestPaint(); }
                }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }
        }

        // live "now" marker: red vertical stripe at the window position of now, near
        // the left edge, drifting right until the next refetch. Rounded caps, always shown.
        Rectangle {
            width: Math.max(4, Shape.borderWidth)
            height: ribbon.height
            x: root.livePos * ribbon.width - width / 2
            radius: width / 2
            color: Colors.nowMarker
        }

        // scrub marker: neutral, only while dragging the ribbon
        Rectangle {
            visible: root.scrubbing
            width: 2
            height: ribbon.height
            x: root.scrubPos * ribbon.width - 1
            color: Colors.textColor
            Rectangle {
                width: 10; height: 10
                radius: Shape.usesBlur ? 5 : 2
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                color: Colors.pillBackground
                border.width: 2
                border.color: Colors.pillBorder
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            function apply(mx) {
                root.scrubPos = Math.max(0, Math.min(1, mx / ribbon.width));
                root.scrubbing = true;
            }
            onPressed: mouse => apply(mouse.x)
            onPositionChanged: mouse => { if (pressed) apply(mouse.x); }
        }
    }

    // ---- scrub time readout ----
    // Floats above the pointer while dragging the ribbon. Child of root, not
    // the clipped ribbon, so it can sit outside the timeline bounds. Tracks the
    // scrub position and instant-follows the pointer (no show/hide animation).
    Rectangle {
        id: scrubLabel
        visible: root.scrubbing && root.svc.ready
        anchors.bottom: ribbon.top
        anchors.bottomMargin: Spacing.spacing4
        x: Math.max(0, Math.min(root.width - width, root.scrubPos * ribbon.width - width / 2))
        width: scrubText.implicitWidth + Spacing.spacing8 * 2
        height: scrubText.implicitHeight + Spacing.spacing4 * 2
        radius: Shape.usesBlur ? height / 2 : Shape.cardRadius
        color: Colors.pillBackground
        border.width: Shape.borderWidth
        border.color: Colors.pillBorder

        Text {
            id: scrubText
            anchors.centerIn: parent
            text: root._fmtHour(root._posClock(root.scrubPos))
            font { family: Typography.fontFamily; pixelSize: Typography.fontSize12; weight: Typography.weightBold }
            color: Colors.textColor
        }
    }

    // ---- axis ----
    Item {
        anchors.top: ribbon.bottom
        anchors.topMargin: Spacing.spacing4
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.axisHeight
        visible: root.svc.ready

        // Clock-hour ticks at now, +6h, +12h, +18h, +24h across the rolling window.
        Repeater {
            model: 5
            delegate: Text {
                required property int index
                readonly property real frac: index / 4
                x: frac * parent.width - (index === 0 ? 0 : (index === 4 ? width : width / 2))
                text: {
                    const hh = ((root.svc.windowStartHour + index * 6) % 24 + 24) % 24;
                    return hh < 10 ? "0" + hh : "" + hh;
                }
                font { family: Typography.fontFamily; pixelSize: Typography.fontSize12; weight: Typography.weightNormal }
                color: Colors.textColorMuted
            }
        }
    }
}

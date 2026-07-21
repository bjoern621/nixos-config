import QtQuick
import "../"
import "../base"
import "WeatherUtils.js" as WeatherUtils

// Calendar weather panel: a stylized sky scene (SkyScene) over a day-timeline
// ribbon. The scene reflects the current hour by default; dragging the ribbon
// scrubs it. Animation runs only while the calendar menu is open.
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

    // Live wall-clock hour; scrubbing overrides it until the menu is reopened.
    readonly property real liveHour: {
        const d = Clock.date;
        return d.getHours() + d.getMinutes() / 60;
    }
    property bool scrubbing: false
    property real scrubHour: 12
    readonly property real displayHour: scrubbing ? scrubHour : liveHour

    // Menu close clears a scrub so the next open starts live on "now".
    onActiveChanged: if (!active) scrubbing = false

    function _dayAt(h) {
        const a = root.svc.dayHours;
        if (!a || !a.length)
            return null;
        return a[Math.max(0, Math.min(23, Math.floor(h)))];
    }
    function _tempAt(h) {
        const a = root.svc.dayHours;
        if (!a || !a.length)
            return root.svc.currentTemp;
        const i = Math.floor(h) % 24, f = h - Math.floor(h), j = (i + 1) % 24;
        const ei = a[i], ej = a[j];
        if (!ei)
            return root.svc.currentTemp;
        if (!ej)
            return ei.temp;
        return ei.temp + (ej.temp - ei.temp) * f;
    }

    // Fractional hour to "HH:MM". Clamps to the 0..24 scrub range.
    function _fmtHour(h) {
        const total = Math.round(Math.max(0, Math.min(24, h)) * 60);
        const hh = Math.floor(total / 60), mm = total % 60;
        return (hh < 10 ? "0" + hh : hh) + ":" + (mm < 10 ? "0" + mm : mm);
    }

    readonly property var _cur: _dayAt(displayHour)
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
            hour: root.displayHour
            condition: root._base
            temp: root._tempAt(root.displayHour)
            animating: root.active && root.svc.ready
        }

        // Current temperature. No chrome; ink outline keeps it legible over any sky.
        Text {
            x: Spacing.spacing12
            y: Spacing.spacing8
            text: Math.round(root._tempAt(root.displayHour)) + "°"
            font { family: Typography.fontFamily; pixelSize: Typography.fontSize32; weight: Typography.weightHeavy }
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
        clip: true

        readonly property real segW: width / 24

        // color band + curve, masked to the ribbon's rounded corners.
        // clip is rectangular; layer.enabled rounds the corners so the band
        // does not square off inside the rounded ink frame.
        Rectangle {
            anchors.fill: parent
            radius: ribbon.radius
            color: "transparent"
            clip: true
            layer.enabled: true

            Repeater {
                model: root.svc.dayHours
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    x: index * ribbon.segW
                    width: ribbon.segW + 1
                    height: ribbon.height
                    color: modelData ? WeatherUtils.conditionColor(modelData.base, modelData.isDay) : "transparent"
                }
            }

            // temperature curve over the segments
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

        // ink frame above the color band (segments fill edge-to-edge and would hide a plain border)
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: ribbon.radius
            border.width: Shape.borderWidth
            border.color: Colors.pillBorder
        }

        // live "now" marker: red vertical stripe at wall-clock hour, rounded caps, always shown
        Rectangle {
            width: Math.max(4, Shape.borderWidth)
            height: ribbon.height
            x: root.liveHour / 24 * ribbon.width - width / 2
            radius: width / 2
            color: Colors.nowMarker
        }

        // scrub marker: neutral, only while dragging the ribbon
        Rectangle {
            visible: root.scrubbing
            width: 2
            height: ribbon.height
            x: root.scrubHour / 24 * ribbon.width - 1
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
                root.scrubHour = Math.max(0, Math.min(24, mx / ribbon.width * 24));
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
        x: Math.max(0, Math.min(root.width - width, root.scrubHour / 24 * ribbon.width - width / 2))
        width: scrubText.implicitWidth + Spacing.spacing8 * 2
        height: scrubText.implicitHeight + Spacing.spacing4 * 2
        radius: Shape.usesBlur ? height / 2 : Shape.cardRadius
        color: Colors.pillBackground
        border.width: Shape.borderWidth
        border.color: Colors.pillBorder

        Text {
            id: scrubText
            anchors.centerIn: parent
            text: root._fmtHour(root.scrubHour)
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

        Repeater {
            model: [["00", 0], ["06", 0.25], ["12", 0.5], ["18", 0.75], ["24", 1]]
            delegate: Text {
                required property var modelData
                x: modelData[1] * parent.width - (modelData[1] === 0 ? 0 : (modelData[1] === 1 ? width : width / 2))
                text: modelData[0]
                font { family: Typography.fontFamily; pixelSize: Typography.fontSize12; weight: Typography.weightNormal }
                color: Colors.textColorMuted
            }
        }
    }
}

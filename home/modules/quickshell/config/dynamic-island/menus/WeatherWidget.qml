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

    readonly property var _cur: _dayAt(displayHour)
    readonly property string _base: _cur ? _cur.base : "clear"
    readonly property var _desc: _cur ? WeatherUtils.describe(_cur.code, _cur.isDay) : ({ icon: "wx-cloudy", label: "" })

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
        border.width: Shape.thinBorderWidth
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

        // HUD chip
        Rectangle {
            id: hud
            x: Spacing.spacing12
            y: Spacing.spacing12
            radius: Spacing.spacing8
            color: Qt.rgba(0.05, 0.06, 0.09, 0.42)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.2)
            width: hudRow.width + Spacing.spacing12 * 2
            height: hudRow.height + Spacing.spacing8 * 2

            Row {
                id: hudRow
                x: Spacing.spacing12
                y: Spacing.spacing8
                spacing: Spacing.spacing8

                TintedIcon {
                    source: "../icons/" + root._desc.icon + ".svg"
                    size: 30
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                        text: {
                            let h = Math.floor(root.displayHour) % 24, m = Math.round((root.displayHour - Math.floor(root.displayHour)) * 60);
                            if (m === 60) { m = 0; h = (h + 1) % 24; }
                            return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
                        }
                        font { family: Typography.fontFamily; pixelSize: Typography.fontSize12; weight: Font.Normal }
                        color: Qt.rgba(1, 1, 1, 0.85)
                    }
                    Text {
                        text: Math.round(root._tempAt(root.displayHour)) + "°"
                        font { family: Typography.fontFamily; pixelSize: Typography.fontSize24; weight: Typography.weightBold }
                        color: "white"
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root._desc.label + (root.svc.city.length ? " · " + root.svc.city : "")
                    font { family: Typography.fontFamily; pixelSize: Typography.fontSize12; weight: Font.Normal }
                    color: Qt.rgba(1, 1, 1, 0.85)
                }
            }
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
        radius: Spacing.spacing4
        color: "transparent"
        border.width: Shape.thinBorderWidth
        border.color: Colors.pillBorder
        clip: true

        readonly property real segW: width / 24

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
                for (let k = 0; k < a.length; k++) {
                    if (!a[k]) continue;
                    const x = (k + 0.5) / 24 * width;
                    const y = height - pad - (a[k].temp - tmin) / (tmax - tmin) * (height - 2 * pad);
                    pts.push([x, y]);
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
            }
            Connections {
                target: root.svc
                function onDayHoursChanged() { curve.requestPaint(); }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        // now / scrub marker
        Rectangle {
            width: 2
            height: ribbon.height
            x: root.displayHour / 24 * ribbon.width - 1
            color: Colors.textColor
            Rectangle {
                width: 10; height: 10; radius: 5
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
                font { family: Typography.fontFamily; pixelSize: Typography.fontSize12; weight: Font.Normal }
                color: Colors.textColorMuted
            }
        }
    }
}

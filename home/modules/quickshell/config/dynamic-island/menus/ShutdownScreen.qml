import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import "../base"
import "../animations"

// Fullscreen overlay showing the list of apps being gracefully closed

Item {
    id: root

    property bool showing: false
    signal cancelled
    signal hidden

    opacity: 0
    visible: opacity > 0
    scale: 0.96
    focus: visible

    transformOrigin: Item.Center

    Keys.onEscapePressed: {
        GracefulShutdown.cancel();
        root.cancelled();
    }

    // -- Shutdown logic (Process needs an Item parent) --

    // Step 1: Fetch all Hyprland clients when activated
    onShowingChanged: {
        if (showing) {
            hideAnim.stop();
            showAnim.start();
            fetchClients.running = true;
        } else {
            showAnim.stop();
            hideAnim.start();
        }
    }

    Process {
        id: fetchClients
        command: ["hyprctl", "clients", "-j"]
        running: false
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                var clients = JSON.parse(data);
                var appList = [];
                for (var i = 0; i < clients.length; i++) {
                    var c = clients[i];
                    appList.push({
                        address: c.address,
                        class: c.class || "unknown",
                        title: c.title || "",
                        alive: true
                    });
                }
                GracefulShutdown.apps = appList;

                // Step 2: Close each window
                for (var j = 0; j < appList.length; j++) {
                    Quickshell.execDetached(["hyprctl", "dispatch", "closewindow", "address:" + appList[j].address]);
                }
                pollTimer.running = true;
            }
        }
    }

    // Step 3: Poll for remaining windows
    Timer {
        id: pollTimer
        interval: 500
        repeat: true
        running: false
        onTriggered: pollClients.running = true
    }

    Process {
        id: pollClients
        command: ["hyprctl", "clients", "-j"]
        running: false
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                var remaining = JSON.parse(data);
                var remainingAddrs = new Set();
                for (var i = 0; i < remaining.length; i++) {
                    remainingAddrs.add(remaining[i].address);
                }

                var currentApps = GracefulShutdown.apps;
                var updated = [];
                for (var j = 0; j < currentApps.length; j++) {
                    var app = currentApps[j];
                    updated.push({
                        address: app.address,
                        class: app.class,
                        title: app.title,
                        alive: remainingAddrs.has(app.address)
                    });
                }
                GracefulShutdown.apps = updated;

                // All windows gone → run post command
                if (remaining.length === 0) {
                    pollTimer.running = false;
                    if (GracefulShutdown.postCmd.length > 0) {
                        Quickshell.execDetached(GracefulShutdown.postCmd);
                    }
                    GracefulShutdown.finished();
                }
            }
        }
    }

    // -- UI --

    transform: Translate {
        id: slideTransform
        y: Spacing.spacing8
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)

        // Cancel button
        Rectangle {
            id: exitButton
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Spacing.spacing24
            width: 40
            height: 40
            radius: height / 2
            opacity: exitHover.hovered ? 1 : 0
            color: exitTap.pressed ? Colors.hoverItemPressed : exitHover.hovered ? Colors.hoverItemHovered : "transparent"
            border.color: exitHover.hovered || exitTap.pressed ? Colors.pillBorder : "transparent"

            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            scale: exitTap.pressed ? 0.85 : 1.0
            SquishBehavior on scale {}

            TintedIcon {
                anchors.centerIn: parent
                source: "../icons/icons8-close.svg"
                size: Typography.fontSize16
                color: Colors.textColor
            }

            HoverHandler {
                id: exitHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: exitTap
                onTapped: {
                    pollTimer.running = false;
                    GracefulShutdown.cancel();
                    root.cancelled();
                }
            }
        }

        // Center content
        Column {
            anchors.centerIn: parent
            spacing: Spacing.spacing24
            width: 320

            // Spinner
            Item {
                width: 60
                height: 60
                anchors.horizontalCenter: parent.horizontalCenter

                Canvas {
                    id: spinnerCanvas
                    anchors.fill: parent

                    property real angle: 0
                    property real sweep: 0

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.clearRect(0, 0, width, height);
                        ctx.strokeStyle = Colors.accentColor;
                        ctx.lineWidth = 6;
                        ctx.lineCap = "round";

                        var centerX = width / 2;
                        var centerY = height / 2;
                        var radius = width / 2 - 4;

                        var startAngle = (angle - 90) * Math.PI / 180;
                        var endAngle = (angle + sweep - 90) * Math.PI / 180;

                        ctx.beginPath();
                        ctx.arc(centerX, centerY, radius, startAngle, endAngle);
                        ctx.stroke();
                    }

                    NumberAnimation on angle {
                        from: 0
                        to: 360
                        duration: 1800
                        loops: Animation.Infinite
                        running: root.visible
                        easing.type: Easing.Linear
                    }

                    SequentialAnimation on sweep {
                        running: root.visible
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: 30
                            to: 240
                            duration: 2100
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            from: 240
                            to: 30
                            duration: 2100
                            easing.type: Easing.InOutSine
                        }
                    }

                    onAngleChanged: requestPaint()
                    onSweepChanged: requestPaint()
                    Component.onCompleted: requestPaint()
                }
            }

            // Action label
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: GracefulShutdown.label
                font.family: Typography.fontFamily
                font.weight: Font.Bold
                font.pixelSize: Typography.fontSize16
                color: Colors.textColor
            }

            // App list
            Column {
                width: parent.width
                spacing: Spacing.spacing4

                Text {
                    text: "Apps werden geschlossen..."
                    font.family: Typography.fontFamily
                    font.weight: Font.Normal
                    font.pixelSize: Typography.fontSize12
                    color: Colors.textColorMuted
                }

                Repeater {
                    model: GracefulShutdown.apps

                    Rectangle {
                        required property var modelData
                        width: parent.width
                        height: 32
                        radius: Spacing.spacing4
                        color: Colors.hoverItemHovered
                        opacity: modelData.alive ? 1.0 : 0.4

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: checkmark.left
                            anchors.leftMargin: Spacing.spacing8
                            anchors.rightMargin: Spacing.spacing8
                            spacing: Spacing.spacing8

                            Text {
                                text: modelData.class
                                font.family: Typography.fontFamily
                                font.weight: Font.Bold
                                font.pixelSize: Typography.fontSize12
                                color: Colors.textColor
                                width: 100
                                elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: modelData.title
                                font.family: Typography.fontFamily
                                font.weight: Font.Normal
                                font.pixelSize: Typography.fontSize12
                                color: Colors.textColorMuted
                                elide: Text.ElideRight
                                width: parent.width - 108
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Checkmark or spinner icon per app
                        Item {
                            id: checkmark
                            anchors.right: parent.right
                            anchors.rightMargin: Spacing.spacing8
                            anchors.verticalCenter: parent.verticalCenter
                            width: Typography.fontSize12
                            height: Typography.fontSize12

                            TintedIcon {
                                id: checkmarkIcon
                                anchors.centerIn: parent
                                source: modelData.alive ? "../icons/icons8-spinner.svg" : "../icons/icons8-done.svg"
                                size: Typography.fontSize12
                                color: modelData.alive ? Colors.textColorMuted : Colors.accentColor
                            }

                            RotationAnimation on rotation {
                                running: modelData.alive
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: 1000
                            }
                        }
                    }
                }
            }
        }
    }

    // Show/hide animations
    ParallelAnimation {
        id: showAnim
        NumberAnimation {
            target: root
            property: "opacity"
            to: 1
            duration: 200
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: slideTransform
            property: "y"
            to: 0
            duration: 200
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "scale"
            to: 1.0
            duration: 250
            easing.type: Easing.OutBack
        }
    }

    ParallelAnimation {
        id: hideAnim
        NumberAnimation {
            target: root
            property: "opacity"
            to: 0
            duration: 150
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: slideTransform
            property: "y"
            to: Spacing.spacing8
            duration: 150
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: root
            property: "scale"
            to: 0.96
            duration: 150
            easing.type: Easing.InCubic
        }
        onFinished: root.hidden()
    }
}

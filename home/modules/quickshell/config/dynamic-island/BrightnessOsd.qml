import Quickshell
import Quickshell.Io
import QtQuick

// Brightness OSD using Quickshell IPC.
// Keybinds call: quickshell ipc call brightness show <value>
// The IpcHandler receives the signal and displays the OSD.
Scope {
    id: brightnessScope

    property int osdValue: 0

    function triggerShow() {
        osdHideTimer.restart()
        hideAnim.stop()
        showAnim.start()
    }

    IpcHandler {
        target: "brightness"

        function show(value: string): void {
            console.log("[BrightnessOSD] received value:", value)
            var val = parseInt(value)
            if (isNaN(val)) {
                console.warn("[BrightnessOSD] ignoring non-integer value:", value)
                return
            }
            brightnessScope.osdValue = Math.min(100, Math.max(0, val))
            brightnessScope.triggerShow()
        }
    }

    Timer {
        id: osdHideTimer
        interval: 2000
        onTriggered: hideAnim.start()
    }

    PanelWindow {
        id: osdWindow

        anchors { top: true }
        exclusiveZone: 0
        color: "transparent"
        readonly property real pillHeight: osdPill.implicitHeight
        readonly property real animOffset: 16
        readonly property real finalY: 36

        implicitWidth: 280
        implicitHeight: finalY + pillHeight + animOffset
        mask: Region {}

        ParallelAnimation {
            id: showAnim
            NumberAnimation { target: osdPill; property: "y"; to: osdWindow.finalY; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: osdPill; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
        }

        ParallelAnimation {
            id: hideAnim
            NumberAnimation { target: osdPill; property: "y"; to: osdWindow.finalY - 16; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: osdPill; property: "opacity"; to: 0; duration: 180; easing.type: Easing.InCubic }
        }

        Rectangle {
            id: osdPill
            x: (osdWindow.width - implicitWidth) / 2
            y: osdWindow.finalY
            opacity: 0

            property var marginTopBottom: 8
            property var marginLeftRight: 12

            implicitWidth: 200
            implicitHeight: contentRow.implicitHeight + 2*marginTopBottom

            radius: implicitHeight / 2
            color: Colors.pillBackground
            border.width: 1
            border.color: Colors.pillBorder

            Row {
                id: contentRow
                anchors {
                    fill: parent
                    leftMargin: osdPill.marginLeftRight
                    rightMargin: osdPill.marginLeftRight
                    topMargin: osdPill.marginTopBottom
                    bottomMargin: osdPill.marginTopBottom
                }
                spacing: 8

                Item {
                    width: 24
                    height: osdIconText.implicitHeight
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: osdIconText
                        text: "\uf185"
                        font.family: Typography.iconFontFamily
                        font.pixelSize: Typography.fontSize16
                        color: Colors.textColor
                        anchors.centerIn: parent
                    }
                }

                Column {
                    spacing: 4
                    width: parent.width - 24 - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter

                    Item {
                        width: parent.width
                        height: labelText.implicitHeight

                        Label {
                            id: labelText
                            text: "Helligkeit"
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Label {
                            text: brightnessScope.osdValue + " %"
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 3

                        Rectangle {
                            width: Math.max(0, (parent.width - 3) * brightnessScope.osdValue / 100)
                            height: 6
                            radius: 3
                            color: Colors.accentColor

                            Behavior on width {
                                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                            }
                        }

                        Rectangle {
                            width: Math.max(0, (parent.width - 3) * (100 - brightnessScope.osdValue) / 100)
                            height: 6
                            radius: 3
                            color: Colors.progressBackground

                            Behavior on width {
                                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }
            }
        }
    }
}

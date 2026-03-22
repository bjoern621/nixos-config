import Quickshell
import Quickshell.Io
import QtQuick

// Brightness OSD – polls brightnessctl to detect changes.
Scope {
    id: brightnessScope

    property bool _startupDone: false
    property int _brightness: -1

    Timer {
        interval: 1000
        running: true
        onTriggered: brightnessScope._startupDone = true
    }

    // Poll brightnessctl regularly
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: brightnessProc.running = true
    }

    Process {
        id: brightnessProc
        command: ["brightnessctl", "-m"]
        stdout: SplitParser {
            onRead: data => {
                // Format: device,class,current,percentage%,max
                const parts = data.split(",")
                if (parts.length >= 4) {
                    const pct = parseInt(parts[3])
                    if (!isNaN(pct) && pct !== brightnessScope._brightness) {
                        brightnessScope._brightness = pct
                    }
                }
            }
        }
    }

    readonly property int osdValue: Math.max(0, Math.min(100, _brightness))
    readonly property string osdIcon: {
        if (osdValue <= 0) return "\uf185"
        if (osdValue < 50) return "\uf185"
        return "\uf185"
    }

    on_BrightnessChanged: {
        if (!_startupDone || _brightness < 0) return
        osdHideTimer.restart()
        hideAnim.stop()
        showAnim.start()
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
            NumberAnimation { target: osdPill; property: "scale"; to: 1.0; duration: 220; easing.type: Easing.OutBack }
        }

        ParallelAnimation {
            id: hideAnim
            NumberAnimation { target: osdPill; property: "y"; to: osdWindow.finalY - 16; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: osdPill; property: "opacity"; to: 0; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: osdPill; property: "scale"; to: 0.96; duration: 180; easing.type: Easing.InCubic }
        }

        Rectangle {
            id: osdPill
            x: (osdWindow.width - implicitWidth) / 2
            y: osdWindow.finalY - osdWindow.animOffset
            opacity: 0
            scale: 0.96
            transformOrigin: Item.Top

            property int marginTopBottom: Spacing.spacing8
            property int marginLeftRight: Spacing.spacing12

            implicitWidth: 200
            implicitHeight: contentRow.implicitHeight + 2*marginTopBottom

            radius: implicitHeight / 2
            color: Colors.pillBackground
            border.width: 1
            border.color: Colors.pillBorder

            Row {
                id: contentRow
                anchors {
                    fill:parent
                    leftMargin: osdPill.marginLeftRight
                    rightMargin: osdPill.marginLeftRight
                    topMargin: osdPill.marginTopBottom
                    bottomMargin: osdPill.marginTopBottom
                }
                spacing: Spacing.spacing8

                Item {
                    width: 24
                    height: osdIconText.implicitHeight
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: osdIconText
                        text: brightnessScope.osdIcon
                        font.family: Typography.iconFontFamily
                        font.pixelSize: Typography.fontSize16
                        color: Colors.textColor
                        anchors.centerIn: parent
                    }
                }

                Column {
                    spacing: Spacing.spacing4
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
                            color: Colors.textColor
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: brightnessScope.osdValue > 0 && brightnessScope.osdValue < 100 ? 3 : 0

                        Rectangle {
                            width: Math.max(0, (parent.width - (brightnessScope.osdValue > 0 && brightnessScope.osdValue < 100 ? 3 : 0)) * brightnessScope.osdValue / 100)
                            height: 6
                            radius: 3
                            color: Colors.accentColor

                            Behavior on width {
                                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                            }
                        }

                        Rectangle {
                            width: Math.max(0, (parent.width - (brightnessScope.osdValue > 0 && brightnessScope.osdValue < 100 ? 3 : 0)) * (100 - brightnessScope.osdValue) / 100)
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

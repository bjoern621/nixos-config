import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import "../"

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

    function focusedScreen() {
        const mon = Hyprland.focusedMonitor
        if (mon) {
            const screens = Quickshell.screens
            for (let i = 0; i < screens.length; i++) {
                if (screens[i].name === mon.name)
                    return screens[i]
            }
        }
        return null
    }

    on_BrightnessChanged: {
        if (!_startupDone || _brightness < 0) return
        const s = focusedScreen()
        if (s) osdWindow.screen = s
        osdHideTimer.restart()
        osdReveal.show()
    }

    Timer {
        id: osdHideTimer
        interval: 2000
        onTriggered: osdReveal.hide()
    }

    PanelWindow {
        id: osdWindow

        anchors { top: true }
        exclusiveZone: 0
        color: "transparent"

        implicitWidth: 280
        implicitHeight: 40 + osdPill.implicitHeight + Spacing.spacing16
        mask: Region {}

        PopReveal {
            id: osdReveal
            x: (osdWindow.width - width) / 2
            y: 40
            width: 200
            height: osdPill.implicitHeight
            showDuration: 120
            hideDuration: 100
            slideOffset: Spacing.spacing16

            Rectangle {
                id: osdPill
                anchors.fill: parent

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
                        fill: parent
                        leftMargin: osdPill.marginLeftRight
                        rightMargin: osdPill.marginLeftRight
                        topMargin: osdPill.marginTopBottom
                        bottomMargin: osdPill.marginTopBottom
                    }
                spacing: Spacing.spacing8

                Icon {
                    text: brightnessScope.osdIcon
                    font.pixelSize: Typography.fontSize16
                    width: 24
                    height: implicitHeight
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
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
}

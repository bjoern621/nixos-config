import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import QtQuick
import "../"

// Volume OSD using Quickshell.Services.Pipewire.
// PwObjectTracker keeps Pipewire.defaultAudioSink alive and data current.
// Connections listens directly to volume/mute changes on the sink's audio node.
Scope {
    id: volumeScope

    property bool suppressOsd: Globals.volumeSliderOpen
    property bool _startupDone: false

    Timer {
        interval: 1000
        running: true
        onTriggered: volumeScope._startupDone = true
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    // Actual volume percentage (can exceed 100 with software boost)
    readonly property int actualVolume: Math.round((Pipewire.defaultAudioSink?.audio.volume ?? 0) * 100)
    // Capped value for progress bar (max 100)
    readonly property int osdValue: Math.min(100, actualVolume)
    readonly property bool isMuted: Pipewire.defaultAudioSink?.audio.muted ?? false

    onActualVolumeChanged: triggerShow()
    onIsMutedChanged: triggerShow()
    readonly property string osdIcon: {
        if (isMuted || osdValue === 0) return "\uf026"
        if (osdValue < 50) return "\uf027"
        return "\uf028"
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

    function triggerShow() {
        if (suppressOsd || !_startupDone) return
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
            showDuration: 200
            hideDuration: 180
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

                    Item {
                        width: 24
                        height: osdIconText.implicitHeight
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: osdIconText
                            text: volumeScope.osdIcon
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
                                text: "Lautstärke"
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Label {
                                text: volumeScope.isMuted ? "stumm" : (volumeScope.actualVolume + " %")
                                color: volumeScope.isMuted ? Colors.textColorMuted : Colors.textColor
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: volumeScope.osdValue > 0 && volumeScope.osdValue < 100 ? 3 : 0

                            Rectangle {
                                width: Math.max(0, (parent.width - (volumeScope.osdValue > 0 && volumeScope.osdValue < 100 ? 3 : 0)) * volumeScope.osdValue / 100)
                                height: 6
                                radius: 3
                                color: volumeScope.isMuted ? Colors.progressMuted : Colors.accentColor

                                Behavior on width {
                                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                                }
                            }

                            Rectangle {
                                width: Math.max(0, (parent.width - (volumeScope.osdValue > 0 && volumeScope.osdValue < 100 ? 3 : 0)) * (100 - volumeScope.osdValue) / 100)
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

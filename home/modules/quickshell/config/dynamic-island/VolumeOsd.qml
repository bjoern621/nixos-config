import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

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

    function triggerShow() {
        if (suppressOsd || !_startupDone) return
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
        }

        ParallelAnimation {
            id: hideAnim
            NumberAnimation { target: osdPill; property: "y"; to: osdWindow.finalY - 16; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: osdPill; property: "opacity"; to: 0; duration: 180; easing.type: Easing.InCubic }
        }

        Rectangle {
            id: osdPill
            x: (osdWindow.width - implicitWidth) / 2
            y: osdWindow.finalY - osdWindow.animOffset
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
                    fill:parent
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
                        text: volumeScope.osdIcon
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

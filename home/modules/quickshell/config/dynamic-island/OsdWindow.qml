import Quickshell
import Quickshell.Io
import QtQuick

// Scope is a non-visual logic container (equivalent to QtObject).
// It holds properties, the FileView watcher, the auto-hide Timer, and
// the PanelWindow as children, without adding any visual layer of its own.
// Instantiate this as VolumeOsd.qml or BrightnessOsd.qml by setting
// watchPath, osdTitle and osdIcon.
Scope {
    id: osdScope

    // --- public interface (set these on VolumeOsd / BrightnessOsd) ---
    // Path of the file to watch. The keybind writes an integer 0-100 followed by a newline.
    property string watchPath: ""
    property string osdTitle: ""
    property string osdIcon: ""

    // --- internal state ---
    property int osdValue: 0

    // Process runs `tail -f --retry -n 0 <path>`.
    // -n 0        : start from the end of the file, so existing content is skipped.
    // -f          : follow new content as it is appended.
    // --retry     : keep trying if the file does not exist yet at startup,
    //               which avoids the race condition between exec-once touch and
    //               quickshell launch.
    // SplitParser splits stdout on newlines and delivers each line to onRead.
    // This is far more reliable than FileView.watchChanges because tail -f is
    // backed by inotify and is battle-tested for exactly this use case.
    Process {
        id: watchProcess
        command: ["tail", "-f", "--retry", "-n", "0", osdScope.watchPath]
        running: true

        Component.onCompleted:
            console.log("[OSD]", osdScope.osdTitle, "tail process started, watching:", osdScope.watchPath)

        onRunningChanged:
            console.log("[OSD]", osdScope.osdTitle, "tail running:", watchProcess.running)

        stdout: SplitParser {
            onRead: data => {
                console.log("[OSD]", osdScope.osdTitle, "received line:", JSON.stringify(data))
                var val = parseInt(data)
                if (isNaN(val)) {
                    console.warn("[OSD]", osdScope.osdTitle, "ignoring non-integer line:", JSON.stringify(data))
                    return
                }
                osdScope.osdValue = Math.min(100, Math.max(0, val))
                console.log("[OSD]", osdScope.osdTitle, "showing value:", osdScope.osdValue)
                osdHideTimer.restart()
                // Stop any in-progress hide and animate to visible.
                // NumberAnimation interpolates FROM the current value, so if the
                // pill is already fully visible this is effectively a no-op.
                hideAnim.stop()
                showAnim.start()
            }
        }
    }

    Timer {
        id: osdHideTimer
        interval: 2000
        onTriggered: hideAnim.start()
    }

    PanelWindow {
        id: osdWindow

        // Only anchor top — no left/right — so the surface is pillWidth wide and
        // centered by the compositor. A full-width surface would cover the entire
        // top edge and intercept all pointer events in that strip.
        anchors { top: true }
        exclusiveZone: 0
        color: "transparent"

        implicitWidth: 332
        implicitHeight: 130

        // mask: Region {} — an empty input region tells the compositor to forward
        // every pointer/scroll event through this window to whatever is below.
        // This is the official Quickshell solution for non-interactive overlays.
        mask: Region {}

        readonly property real finalY: 46

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
            y: osdWindow.finalY - 16
            opacity: 0

            implicitWidth: 300
            implicitHeight: 76

            radius: 16
            color: Colors.osdPillBackground

            border.width: 1
            border.color: Colors.osdPillBorder

            Row {
                anchors {
                    fill: parent
                    leftMargin: 16
                    rightMargin: 16
                    topMargin: 14
                    bottomMargin: 14
                }
                spacing: 14

                Text {
                    id: osdIconText
                    text: osdScope.osdIcon
                    font.family: Typography.iconFontFamily
                    font.pixelSize: Typography.fontSize20
                    color: Colors.textColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    spacing: 7
                    width: parent.width - osdIconText.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter

                    Item {
                        width: parent.width
                        height: osdLabel.implicitHeight

                        Label {
                            id: osdLabel
                            text: osdScope.osdTitle
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Label {
                            text: osdScope.osdValue
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 3

                        Rectangle {
                            width: Math.max(0, (parent.width - 3) * osdScope.osdValue / 100)
                            height: 6
                            radius: 3
                            color: Colors.accentColor

                            Behavior on width {
                                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                            }
                        }

                        Rectangle {
                            width: Math.max(0, (parent.width - 3) * (100 - osdScope.osdValue) / 100)
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

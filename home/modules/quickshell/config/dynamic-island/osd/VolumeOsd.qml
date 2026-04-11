import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import QtQuick
import "../"
import "../base"

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
    readonly property string osdIconSource: {
        if (isMuted || osdValue === 0)
            return "../icons/icons8-sound-speaker.svg";
        if (osdValue <= 33)
            return "../icons/icons8-low-volume.svg";
        if (osdValue <= 66)
            return "../icons/icons8-volume.svg";
        return "../icons/icons8-audio.svg";
    }

    function focusedScreen() {
        const mon = Hyprland.focusedMonitor;
        if (mon) {
            const screens = Quickshell.screens;
            for (let i = 0; i < screens.length; i++) {
                if (screens[i].name === mon.name)
                    return screens[i];
            }
        }
        return null;
    }

    function triggerShow() {
        if (suppressOsd || !_startupDone)
            return;
        const s = focusedScreen();
        if (s)
            osdWindow.screen = s;
        osdWindow.visible = true;
        osdHideTimer.restart();
        osdReveal.show();
    }

    Timer {
        id: osdHideTimer
        interval: 2000
        onTriggered: osdReveal.hide()
    }

    PanelWindow {
        id: osdWindow
        visible: false

        anchors {
            top: true
        }
        exclusiveZone: 0
        color: "transparent"

        implicitWidth: 280
        implicitHeight: 40 + osdPill.implicitHeight + Spacing.spacing16
        mask: Region {}

        Connections {
            target: osdReveal
            function onHidden() {
                osdWindow.visible = false;
            }
        }

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
                implicitHeight: contentRow.implicitHeight + 2 * marginTopBottom

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

                    ContentReplace {
                        id: osdIconReplace
                        width: 24
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter
                        contentKey: volumeScope.osdIconSource

                        Item {
                            id: osdIconText
                            width: 22
                            height: 22
                            x: 1
                            y: 1

                            TintedIcon {
                                anchors.centerIn: parent
                                size: 22
                                source: osdIconReplace.displayValue
                            }
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

                            ContentReplace {
                                id: volLabelReplace
                                contentKey: volumeScope.isMuted ? "muted" : volumeScope.actualVolume
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: volLabel.implicitWidth
                                height: volLabel.implicitHeight

                                Label {
                                    id: volLabel
                                    text: volLabelReplace.displayValue === "muted" ? "stumm" : (volLabelReplace.displayValue + " %")
                                    color: volLabelReplace.displayValue === "muted" ? Colors.textColorMuted : Colors.textColor
                                }
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
                                    NumberAnimation {
                                        duration: 120
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            Rectangle {
                                width: Math.max(0, (parent.width - (volumeScope.osdValue > 0 && volumeScope.osdValue < 100 ? 3 : 0)) * (100 - volumeScope.osdValue) / 100)
                                height: 6
                                radius: 3
                                color: Colors.progressBackground

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 120
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

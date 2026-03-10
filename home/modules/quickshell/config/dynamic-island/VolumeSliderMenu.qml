import Quickshell.Services.Pipewire
import QtQuick

Item {
    id: sliderMenu

    readonly property bool menuHovered: hoverHandler.hovered
    readonly property bool sliderActive: sliderArea.pressed
    readonly property bool keepOpen: menuHovered || sliderActive

    signal hidden()

    implicitHeight: 40
    opacity: 0
    visible: opacity > 0

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    readonly property var audioNode: Pipewire.defaultAudioSink?.audio ?? null
    readonly property int currentVolume: Math.round((audioNode?.volume ?? 0) * 100)
    readonly property bool isMuted: audioNode?.muted ?? false
    readonly property string volumeIcon: {
        if (isMuted || currentVolume === 0) return "\uf026"
        if (currentVolume < 50) return "\uf027"
        return "\uf028"
    }

    HoverHandler {
        id: hoverHandler
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Colors.pillBackground
        border.width: 1
        // border.color: Colors.pillBorder
        border.color: "Blue"

        Text {
            id: volIcon
            text: sliderMenu.volumeIcon
            font.family: Typography.iconFontFamily
            font.pixelSize: Typography.fontSize14
            color: Colors.textColor
            anchors {
                left: parent.left
                leftMargin: 16
                verticalCenter: parent.verticalCenter
            }
            width: 16
            horizontalAlignment: Text.AlignHCenter
        }

        Label {
            id: pctLabel
            text: sliderMenu.currentVolume + "%"
            anchors {
                right: parent.right
                rightMargin: 16
                verticalCenter: parent.verticalCenter
            }
            width: 40
            horizontalAlignment: Text.AlignRight
        }

        Item {
            id: sliderTrack
            anchors {
                left: volIcon.right
                leftMargin: 10
                right: pctLabel.left
                rightMargin: 10
                verticalCenter: parent.verticalCenter
            }
            height: 6

            Rectangle {
                anchors.fill: parent
                radius: 3
                color: Colors.progressBackground
            }

            Rectangle {
                width: Math.max(6, parent.width * Math.min(1, sliderMenu.audioNode?.volume ?? 0))
                height: 6
                radius: 3
                color: sliderMenu.isMuted ? Colors.progressMuted : Colors.accentColor

                Behavior on width {
                    enabled: !sliderArea.pressed
                    NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
                }
            }

            Rectangle {
                x: Math.max(0, Math.min(sliderTrack.width - width,
                    sliderTrack.width * Math.min(1, sliderMenu.audioNode?.volume ?? 0) - width / 2))
                y: (sliderTrack.height - height) / 2
                width: 14
                height: 14
                radius: 7
                color: "#ffffff"
                border.width: 2
                border.color: sliderMenu.isMuted ? Colors.progressMuted : Colors.accentColor

                Behavior on x {
                    enabled: !sliderArea.pressed
                    NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
                }
            }

            MouseArea {
                id: sliderArea
                anchors {
                    fill: parent
                    topMargin: -14
                    bottomMargin: -14
                }

                onPressed: (mouse) => updateVolume(mouse.x)
                onPositionChanged: (mouse) => {
                    if (pressed) updateVolume(mouse.x)
                }

                function updateVolume(mouseX) {
                    var fraction = Math.max(0, Math.min(1, mouseX / sliderTrack.width))
                    if (sliderMenu.audioNode)
                        sliderMenu.audioNode.volume = fraction
                }
            }
        }
    }

    NumberAnimation {
        id: showAnim
        target: sliderMenu
        property: "opacity"
        to: 1
        duration: 150
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: hideAnim
        target: sliderMenu
        property: "opacity"
        to: 0
        duration: 150
        easing.type: Easing.InCubic
        onStopped: sliderMenu.hidden()
    }

    function show() {
        hideAnim.stop()
        showAnim.start()
    }

    function hide() {
        showAnim.stop()
        hideAnim.start()
    }
}

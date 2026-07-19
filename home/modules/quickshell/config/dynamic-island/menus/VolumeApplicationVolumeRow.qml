pragma ComponentBehavior: Bound

import QtQuick
import "../"
import "../base"

Column {
    id: root

    required property var streamNode
    property var controller
    // Read by the menu to keep itself open during a drag. A property, not a
    // press/release signal: a row destroyed mid-drag emits no release.
    readonly property bool sliderPressed: appSlider.pressed

    width: parent ? parent.width : 0
    spacing: Spacing.spacing4

    readonly property var appAudio: streamNode.audio

    readonly property int appVolume: Math.round((appAudio?.volume ?? 0) * 100)
    readonly property bool appMuted: appAudio?.muted ?? false
    readonly property url appIconSource: VolumeService.iconFor(root.appVolume, root.appMuted)

    Item {
        width: parent.width
        height: 24

        Label {
            text: root.streamNode.description || root.streamNode.name
            font.pixelSize: Typography.fontSize12
            elide: Text.ElideRight
            anchors {
                left: parent.left
                right: appMuteButton.left
                rightMargin: Spacing.spacing8
                verticalCenter: parent.verticalCenter
            }
        }

        VolumeMuteButton {
            id: appMuteButton
            width: 24
            height: 24
            iconSize: 16
            iconSource: root.appIconSource
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            onTapped: root.controller.toggleAppMute(root.streamNode)
        }
    }

    Row {
        width: parent.width
        spacing: Spacing.spacing8

        StepSlider {
            id: appSlider
            width: parent.width - appPct.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            externalValue: root.appAudio?.volume ?? 0
            stepSize: 0.05
            isMuted: root.appMuted
            handleVerticalSize: 16

            onMoved: newValue => root.controller.setAppVolume(root.streamNode, newValue)
        }

        Label {
            id: appPct
            text: root.appVolume + "%"
            width: 36
            horizontalAlignment: Text.AlignRight
            font.pixelSize: Typography.fontSize12
            font.weight: Font.Normal
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}

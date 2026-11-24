pragma ComponentBehavior: Bound

import QtQuick
import "../"
import "../base"

// One labelled level under "Anwendungen": name, mute button, slider, percent.
// Owners map their source onto level (0-1) and handle the signals.
Column {
    id: root

    property string title: ""
    property real level: 0
    property bool muted: false
    // Read by the menu to keep itself open during a drag. A property, not a
    // press/release signal: a row destroyed mid-drag emits no release.
    readonly property bool sliderPressed: levelSlider.pressed

    signal moved(real newLevel)
    signal muteTapped

    readonly property int percent: Math.round(root.level * 100)

    width: parent ? parent.width : 0
    spacing: Spacing.spacing4

    Item {
        width: parent.width
        height: 24

        Label {
            text: root.title
            font.pixelSize: Typography.fontSize12
            elide: Text.ElideRight
            anchors {
                left: parent.left
                right: muteButton.left
                rightMargin: Spacing.spacing8
                verticalCenter: parent.verticalCenter
            }
        }

        VolumeMuteButton {
            id: muteButton
            width: 24
            height: 24
            iconSize: 16
            iconSource: VolumeService.iconFor(root.percent, root.muted)
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            onTapped: root.muteTapped()
        }
    }

    Row {
        width: parent.width
        spacing: Spacing.spacing8

        StepSlider {
            id: levelSlider
            width: parent.width - pct.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            externalValue: root.level
            stepSize: 0.05
            isMuted: root.muted
            handleVerticalSize: 16

            onMoved: newValue => root.moved(newValue)
        }

        Label {
            id: pct
            text: root.percent + "%"
            width: 36
            horizontalAlignment: Text.AlignRight
            font.pixelSize: Typography.fontSize12
            font.weight: Font.Normal
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}

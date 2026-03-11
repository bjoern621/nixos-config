import QtQuick

Item {
    id: root

    property real value: 0
    property real stepSize: 0.05
    property bool isMuted: false
    property color accentColor: Colors.accentColor
    property color mutedColor: Colors.progressMuted
    property color trackColor: Colors.progressBackground
    property int handleVerticalSize: 20

    signal moved(real newValue)

    implicitHeight: 8

    readonly property bool pressed: sliderArea.pressed

    property real externalValue: 0

    readonly property color fillColor: root.isMuted ? root.mutedColor : root.accentColor

    Binding {
        target: root
        property: "value"
        value: root.externalValue
        when: !root.pressed
        restoreMode: Binding.RestoreBinding
    }

    Item {
        id: fillTrack
        anchors {
            left: parent.left
            right: handle.horizontalCenter
            rightMargin: Spacing.spacing6
            verticalCenter: parent.verticalCenter
        }
        height: 8
        clip: true

        Rectangle {
            width: fillTrack.width + 4
            height: 8
            radius: 4
            color: root.fillColor
        }

        Behavior on width {
            enabled: !sliderArea.pressed
            NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
        }
    }

    Rectangle {
        id: handle
        x: Math.max(0, Math.min(root.width - width,
            root.width * Math.min(1, root.value) - width / 2))
        y: (root.height - height) / 2
        width: 4
        height: root.handleVerticalSize
        radius: root.handleVerticalSize / 2
        color: root.fillColor

        Behavior on x {
            enabled: !sliderArea.pressed
            NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
        }
    }

    Item {
        id: emptyTrack
        anchors {
            left: handle.horizontalCenter
            leftMargin: Spacing.spacing6
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        height: 8
        clip: true

        Rectangle {
            x: -4
            width: emptyTrack.width + 4
            height: 8
            radius: 4
            color: root.trackColor
        }
    }

    function updateValue(mouseX) {
        var rawFraction = Math.max(0, Math.min(1, mouseX / root.width))
        var steppedValue = Math.round(rawFraction / root.stepSize) * root.stepSize
        root.value = steppedValue
        root.moved(steppedValue)
    }

    MouseArea {
        id: sliderArea
        anchors {
            fill: parent
            topMargin: -root.handleVerticalSize
            bottomMargin: -root.handleVerticalSize
        }

        onPressed: (mouse) => root.updateValue(mouse.x)
        onPositionChanged: (mouse) => {
            if (pressed) root.updateValue(mouse.x)
        }
    }
}

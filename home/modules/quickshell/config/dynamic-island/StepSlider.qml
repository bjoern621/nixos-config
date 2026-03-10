import QtQuick

Item {
    id: root

    property real value: 0
    property real stepSize: 0.05
    property bool isMuted: false
    property color accentColor: Colors.accentColor
    property color mutedColor: Colors.progressMuted
    property color trackColor: Colors.progressBackground
    property int handleSize: 14

    signal moved(real newValue)

    implicitHeight: 6

    readonly property bool pressed: sliderArea.pressed

    Rectangle {
        anchors.fill: parent
        radius: 3
        color: root.trackColor
    }

    Rectangle {
        width: Math.max(6, parent.width * Math.min(1, root.value))
        height: 6
        radius: 3
        color: root.isMuted ? root.mutedColor : root.accentColor

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
        width: root.handleSize
        height: root.handleSize
        radius: root.handleSize / 2
        color: "#ffffff"
        border.width: 2
        border.color: root.isMuted ? root.mutedColor : root.accentColor

        Behavior on x {
            enabled: !sliderArea.pressed
            NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        id: sliderArea
        anchors {
            fill: parent
            topMargin: -root.handleSize
            bottomMargin: -root.handleSize
        }

        onPressed: (mouse) => root.updateValue(mouse.x)
        onPositionChanged: (mouse) => {
            if (pressed) root.updateValue(mouse.x)
        }

        function updateValue(mouseX) {
            var rawFraction = Math.max(0, Math.min(1, mouseX / root.width))
            var steppedValue = Math.round(rawFraction / root.stepSize) * root.stepSize
            root.value = steppedValue
            root.moved(steppedValue)
        }
    }
}

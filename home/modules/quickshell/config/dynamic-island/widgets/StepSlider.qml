import QtQuick
import "../"

Item {
    id: root

    property real value: 0
    property real stepSize: 0.05
    property bool isMuted: false // grays out the fill color
    property color accentColor: Colors.accentColor
    property color mutedColor: Colors.progressMuted
    property color trackColor: Colors.progressBackground
    property int handleVerticalSize: 20
    property int trackPadding: 4 // insets handle range so tracks stay visible at 0% and 100%

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
        x: root.trackPadding + (root.width - 2 * root.trackPadding - width) * Math.max(0, Math.min(1, root.value))
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
        var usable = root.width - 2 * root.trackPadding
        var rawFraction = Math.max(0, Math.min(1, (mouseX - root.trackPadding) / usable))
        var steppedValue = Math.round(rawFraction / root.stepSize) * root.stepSize
        root.value = steppedValue
        root.moved(steppedValue)
    }

    property real scrollAccumulator: 0
    property int touchpadThreshold: 50
    property int mouseThreshold: 120

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
        onWheel: (wheel) => {
            var delta = wheel.angleDelta.y
            var threshold = Math.abs(delta) >= root.mouseThreshold ? root.mouseThreshold : root.touchpadThreshold
            root.scrollAccumulator += delta
            while (Math.abs(root.scrollAccumulator) >= threshold) {
                var direction = root.scrollAccumulator > 0 ? 1 : -1
                root.scrollAccumulator -= direction * threshold
                var steppedValue = Math.max(0, Math.min(1, root.value + direction * root.stepSize))
                root.value = steppedValue
                root.moved(steppedValue)
            }
        }
    }
}

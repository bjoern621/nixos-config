import QtQuick
import "../"

Item {
    id: root

    property real value: 0
    property real stepSize: 0.05
    property bool isMuted: false
    property color accentColor: Colors.accentColor
    property color mutedColor: Colors.progressMuted
    property color trackColor: Colors.progressBackground
    property int handleVerticalSize: 20
    property int trackPadding: 4 // insets handle range so tracks stay visible at 0% and 100%
    property bool liveUpdate: true // false: moved() fires on release only, not during drag

    signal moved(real newValue)

    implicitHeight: 8

    readonly property bool pressed: sliderArea.pressed

    property real externalValue: 0

    readonly property color fillColor: root.isMuted ? root.mutedColor : root.accentColor

    // Drag and wheel both write `value` imperatively, dropping whatever binding sits on it.
    // `when` must gate this Binding off for the whole span of either gesture.
    // Else the write kills it, and externalValue stops reaching value until
    // the next press re-installs it.
    Binding {
        target: root
        property: "value"
        value: root.externalValue
        when: !root.pressed && !wheelSettle.running
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
            NumberAnimation {
                duration: 80
                easing.type: Easing.OutCubic
            }
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
            NumberAnimation {
                duration: 80
                easing.type: Easing.OutCubic
            }
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
        const usable = root.width - 2 * root.trackPadding;
        const rawFraction = Math.max(0, Math.min(1, (mouseX - root.trackPadding) / usable));
        // Clamp after stepping.
        // Rounding overshoots 1 for a stepSize that does not divide 1:
        // 0.4 rounds to 1.2, while handle.x clamps.
        const steppedValue = Math.max(0, Math.min(1, Math.round(rawFraction / root.stepSize) * root.stepSize));
        root.value = steppedValue;
        if (root.liveUpdate)
            root.moved(steppedValue);
    }

    // Wheel deltas below the threshold must survive across events, else touchpad scroll never steps.
    QtObject {
        id: internal
        property real scrollAccumulator: 0
    }

    property int touchpadThreshold: 50
    property int mouseThreshold: 120

    // Holds the value Binding off past the last wheel event, covering the
    // backend round-trip that feeds externalValue back.
    // Without it the Binding re-installs between wheel events and reverts each
    // step to the stale externalValue.
    Timer {
        id: wheelSettle
        interval: 200
    }

    MouseArea {
        id: sliderArea
        anchors {
            fill: parent
            topMargin: -root.handleVerticalSize
            bottomMargin: -root.handleVerticalSize
        }

        onPressed: mouse => root.updateValue(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                root.updateValue(mouse.x);
        }
        onReleased: {
            if (!root.liveUpdate)
                root.moved(root.value);
        }
        onWheel: wheel => {
            // Restart before writing value: gates the Binding off first, else the write below drops it.
            wheelSettle.restart();
            const delta = wheel.angleDelta.y;
            const threshold = Math.abs(delta) >= root.mouseThreshold ? root.mouseThreshold : root.touchpadThreshold;
            // Threshold 0 never drains the accumulator, so the loop below never terminates.
            if (threshold <= 0)
                return;
            // Reversing drops accumulated travel.
            // Else opposing deltas cancel, and the reversal needs a full threshold of its own to register.
            if (delta * internal.scrollAccumulator < 0)
                internal.scrollAccumulator = 0;
            internal.scrollAccumulator += delta;
            while (Math.abs(internal.scrollAccumulator) >= threshold) {
                const direction = internal.scrollAccumulator > 0 ? 1 : -1;
                internal.scrollAccumulator -= direction * threshold;
                const steppedValue = Math.max(0, Math.min(1, root.value + direction * root.stepSize));
                root.value = steppedValue;
                root.moved(steppedValue);
            }
        }
    }
}

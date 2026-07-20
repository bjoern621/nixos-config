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

    // Classic: segmented thin pills with a gap around a thin capsule handle.
    Item {
        id: fillTrack
        visible: Shape.usesBlur
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

    Item {
        id: emptyTrack
        visible: Shape.usesBlur
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

    // Neo: continuous ink-bordered track, accent fill inset inside the border, under the circular handle.
    Rectangle {
        id: neoTrack
        visible: !Shape.usesBlur
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        height: 8
        radius: height / 2
        color: root.trackColor
        border.width: NeoTokens.thinBorderWidth
        border.color: NeoTokens.ink
        clip: true

        Rectangle {
            id: neoFill
            x: NeoTokens.thinBorderWidth
            y: NeoTokens.thinBorderWidth
            height: parent.height - 2 * NeoTokens.thinBorderWidth
            // fill to handle center, minus left border inset; neoTrack left == root left.
            width: Math.max(0, handle.x + handle.width / 2 - NeoTokens.thinBorderWidth)
            radius: parent.radius - NeoTokens.thinBorderWidth
            color: root.fillColor

            Behavior on width {
                enabled: !sliderArea.pressed
                NumberAnimation {
                    duration: 80
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    // Classic: thin accent capsule (width 4). Neo: paper circle with ink border.
    Rectangle {
        id: handle
        x: root.trackPadding + (root.width - 2 * root.trackPadding - width) * Math.max(0, Math.min(1, root.value))
        y: (root.height - height) / 2
        width: Shape.usesBlur ? 4 : root.handleVerticalSize
        height: root.handleVerticalSize
        radius: root.handleVerticalSize / 2
        color: Shape.usesBlur ? root.fillColor : NeoTokens.paper
        border.width: Shape.usesBlur ? 0 : NeoTokens.borderWidth
        border.color: NeoTokens.ink

        Behavior on x {
            enabled: !sliderArea.pressed
            NumberAnimation {
                duration: 80
                easing.type: Easing.OutCubic
            }
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

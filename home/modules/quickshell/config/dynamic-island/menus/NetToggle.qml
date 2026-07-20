import QtQuick
import "../"
import "../base"
import "../animations"

// Neo switch: ink-bordered track, square knob that slides. Accent when on.
// busy swaps the knob for a spinner (an in-flight radio/vpn toggle).
Item {
    id: root

    property bool checked: false
    property bool busy: false
    signal toggled

    implicitWidth: 42
    implicitHeight: 22

    scale: tap.pressed ? 0.9 : 1.0
    SquishBehavior on scale {}

    Rectangle {
        id: track
        anchors.fill: parent
        radius: 4
        color: root.checked ? Colors.selectedBackground : Colors.progressBackground
        border.width: Shape.thinBorderWidth
        border.color: Colors.pillBorder
    }

    Rectangle {
        id: knob
        width: parent.height - 6
        height: parent.height - 6
        radius: 3
        y: 3
        x: root.checked ? parent.width - width - 3 : 3
        color: Colors.pillBackground
        border.width: Shape.thinBorderWidth
        border.color: Colors.pillBorder
        visible: !root.busy

        // Knob slide has no reusable equivalent; slide it directly.
        Behavior on x {
            NumberAnimation {
                duration: 90
                easing.type: Easing.OutCubic
            }
        }
    }

    TintedIcon {
        id: spinner
        anchors.centerIn: parent
        source: "../icons/icons8-spinner.svg"
        size: parent.height - 8
        color: Colors.textColor
        visible: root.busy
        NumberAnimation on rotation {
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            running: spinner.visible
            easing.type: Easing.Linear
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        id: tap
        enabled: !root.busy
        onTapped: root.toggled()
    }
}

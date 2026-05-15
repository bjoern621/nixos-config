import QtQuick
import "."

TintedIcon {
    id: root

    property bool spinning: visible
    property int spinDuration: 900

    source: "icons/icons8-spinner.svg"
    size: Typography.fontSize20
    color: Colors.textColor
    rotation: 0

    NumberAnimation on rotation {
        from: 0
        to: 360
        duration: root.spinDuration
        loops: Animation.Infinite
        running: root.spinning
        easing.type: Easing.Linear
    }
}

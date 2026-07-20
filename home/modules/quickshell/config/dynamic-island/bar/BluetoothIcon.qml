import QtQuick
import "../"
import "../base"

// Bar Bluetooth indicator: glyph tinted by radio state, accent chip when a
// device is connected. State comes from the BluetoothService singleton,
// matching NetworkIcon's shape.
Item {
    id: root

    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    width: 18
    height: 18

    TintedIcon {
        anchors.fill: parent
        source: "../icons/icons8-bluetooth.svg"
        color: BluetoothService.powered ? Colors.textColor : Colors.textColorMuted
        opacity: BluetoothService.powered ? 1.0 : 0.65
    }

    // Connected: small accent chip in the top-right corner.
    Rectangle {
        visible: BluetoothService.connectedCount > 0
        width: 8
        height: 8
        radius: 2
        x: parent.width - width + 1
        y: -1
        color: Colors.accentColor
        border.width: Shape.thinBorderWidth
        border.color: Colors.pillBorder
    }
}

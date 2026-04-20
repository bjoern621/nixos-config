pragma ComponentBehavior: Bound

import QtQuick
import "../"
import "../base"

Item {
    id: root

    required property var outputDevice
    required property int defaultSinkId
    required property bool btBusy
    required property string btConnectingMac
    required property string btStatusMac
    required property string btStatusText

    signal sinkActivated(var sinkNode)
    signal bluetoothActivated(string deviceName, string mac)

    width: parent ? parent.width : 0

    readonly property string deviceMac: outputDevice.mac ?? ""
    readonly property bool hasBtStatus: outputDevice.isBluetooth && deviceMac.length > 0 && (deviceMac === root.btStatusMac) && root.btStatusText.length > 0
    height: hasBtStatus ? 46 : 32

    readonly property bool isSinkEntry: outputDevice.type === "sink"
    readonly property bool isDefault: isSinkEntry && outputDevice.node.id === root.defaultSinkId
    readonly property bool isBusyTarget: root.btBusy && outputDevice.isBluetooth && (deviceMac === root.btConnectingMac)
    readonly property bool isBluetoothLocked: !isSinkEntry && outputDevice.isBluetooth && root.btBusy

    scale: sinkTap.pressed ? 0.97 : 1.0
    SquishBehavior on scale {}

    Rectangle {
        anchors.fill: parent
        radius: Spacing.spacing8
        color: root.isDefault ? Qt.rgba(1, 1, 1, 0.06) : root.isBluetoothLocked ? Qt.rgba(1, 1, 1, 0.08) : sinkTap.pressed ? Colors.hoverItemPressed : sinkHover.hovered ? Colors.hoverItemHovered : "transparent"
        border.color: root.isDefault ? Colors.accentColor : root.isBluetoothLocked ? Colors.pillBorder : sinkHover.hovered || sinkTap.pressed ? Colors.pillBorder : "transparent"
    }

    Item {
        anchors {
            left: parent.left
            leftMargin: Spacing.spacing8
            right: parent.right
            rightMargin: Spacing.spacing8
            verticalCenter: parent.verticalCenter
        }
        height: parent.height

        Row {
            id: rightStatusIcons
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            spacing: Spacing.spacing8

            Label {
                text: "Gesperrt"
                visible: root.isBluetoothLocked
                font.pixelSize: Typography.fontSize12
                font.weight: Font.Normal
                color: Colors.textColorMuted
                anchors.verticalCenter: parent.verticalCenter
            }

            TintedIcon {
                source: "../icons/icons8-done.svg"
                size: Typography.fontSize14
                color: Colors.accentColor
                visible: root.isDefault && !root.isBusyTarget
                width: visible ? Typography.fontSize12 : 0
                anchors.verticalCenter: parent.verticalCenter
            }

            TintedIcon {
                id: busyIcon
                source: "../icons/icons8-spinner.svg"
                size: Typography.fontSize14
                color: Colors.textColorMuted
                visible: root.isBusyTarget
                width: visible ? Typography.fontSize12 : 0
                rotation: 0
                anchors.verticalCenter: parent.verticalCenter

                NumberAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    running: busyIcon.visible
                    easing.type: Easing.Linear
                }
            }
        }

        Column {
            id: textBlock
            anchors {
                left: parent.left
                right: rightStatusIcons.left
                rightMargin: Spacing.spacing8
                verticalCenter: parent.verticalCenter
            }

            Row {
                id: nameWithBluetooth
                width: parent.width
                spacing: Spacing.spacing4

                Label {
                    text: root.outputDevice.name
                    font.pixelSize: Typography.fontSize12
                    font.weight: root.isDefault ? Font.Bold : Font.Normal
                    color: root.isDefault ? Colors.accentColor : root.isBluetoothLocked ? Colors.textColorMuted : Colors.textColor
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, nameWithBluetooth.width - (bluetoothIcon.visible ? bluetoothIcon.width + nameWithBluetooth.spacing : 0))
                }

                TintedIcon {
                    id: bluetoothIcon
                    source: "../icons/icons8-bluetooth.svg"
                    size: Typography.fontSize14
                    color: root.isDefault ? Colors.accentColor : root.isBluetoothLocked ? Colors.textColorMuted : Colors.textColorMuted
                    visible: root.outputDevice.isBluetooth
                    width: visible ? Typography.fontSize14 : 0
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Label {
                visible: root.hasBtStatus
                width: parent.width
                text: root.btStatusText
                font.pixelSize: Typography.fontSize12
                font.weight: Font.Normal
                color: Colors.textColorMuted
                elide: Text.ElideRight
            }
        }
    }

    HoverHandler {
        id: sinkHover
        cursorShape: root.isBluetoothLocked ? Qt.ForbiddenCursor : Qt.PointingHandCursor
    }
    TapHandler {
        id: sinkTap
        enabled: root.isSinkEntry || !root.btBusy
        onTapped: {
            if (root.isSinkEntry) {
                root.sinkActivated(root.outputDevice.node);
                return;
            }

            root.bluetoothActivated(root.outputDevice.name, root.deviceMac);
        }
    }
}

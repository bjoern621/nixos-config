pragma ComponentBehavior: Bound

import QtQuick
import "../"
import "../base"

Item {
    id: root

    required property var outputDevice
    required property int defaultSinkId

    signal sinkActivated(var sinkNode)
    signal bluetoothActivated(string deviceName, string mac)

    width: parent ? parent.width : 0

    readonly property string deviceMac: outputDevice.mac ?? ""
    readonly property bool hasBtStatus: outputDevice.isBluetooth && deviceMac.length > 0 && (deviceMac === BluetoothConnector.statusMac) && BluetoothConnector.statusText.length > 0
    height: hasBtStatus ? 46 : 32

    readonly property bool isSinkEntry: outputDevice.type === "sink"
    readonly property bool isDefault: isSinkEntry && outputDevice.node.id === root.defaultSinkId
    readonly property bool isBusyTarget: BluetoothConnector.busy && outputDevice.isBluetooth && (deviceMac === BluetoothConnector.connectingMac)
    readonly property bool isBluetoothLocked: !isSinkEntry && outputDevice.isBluetooth && BluetoothConnector.busy

    scale: sinkTap.pressed ? 0.97 : 1.0
    SquishBehavior on scale {}

    // Selected sink = accent + 2px ink border (launcher selection). Locked shows lit cream.
    LauncherDelegateBg {
        active: root.isDefault
        hovered: sinkHover.hovered || root.isBluetoothLocked
        pressed: sinkTap.pressed
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
                // On the selected (accent) background, tint with foreground ink/text.
                color: Colors.textColor
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
                    // Selected row text sits on selectedBackground: use foreground text color.
                    color: root.isBluetoothLocked ? Colors.textColorMuted : Colors.textColor
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, nameWithBluetooth.width - (bluetoothIcon.visible ? bluetoothIcon.width + nameWithBluetooth.spacing : 0))
                }

                TintedIcon {
                    id: bluetoothIcon
                    source: "../icons/icons8-bluetooth.svg"
                    size: Typography.fontSize14
                    color: root.isDefault ? Colors.textColor : Colors.textColorMuted
                    visible: root.outputDevice.isBluetooth
                    width: visible ? Typography.fontSize14 : 0
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Label {
                visible: root.hasBtStatus
                width: parent.width
                text: BluetoothConnector.statusText
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
        enabled: root.isSinkEntry || !BluetoothConnector.busy
        onTapped: {
            if (root.isSinkEntry) {
                root.sinkActivated(root.outputDevice.node);
                return;
            }

            root.bluetoothActivated(root.outputDevice.name, root.deviceMac);
        }
    }
}

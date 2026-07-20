pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth
import "../"
import "../base"
import "../animations"
import "BluetoothMenuUtils.js" as BtUtils

// One Bluetooth device row: type glyph, name, state, battery, plus an expandable
// panel (connect/disconnect, rename, forget, trust, block) for paired devices.
// The menu owns pair/connect/rename decisions; the row only reports intent.
Item {
    id: root

    required property var device
    property bool expanded: false
    // Available (discovered, unpaired) rows are lean: tap to pair, no detail.
    property bool available: false

    signal activated
    signal detailToggled
    signal renameRequested

    readonly property string devName: device ? device.name : ""
    readonly property bool connected: device ? device.connected : false
    readonly property bool paired: device ? (device.paired || device.bonded) : false
    readonly property bool blocked: device ? device.blocked : false
    readonly property bool busy: device && (device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting || device.pairing)
    readonly property int battery: BtUtils.batteryPercent(device)
    readonly property bool hasDetail: paired && !available

    width: parent ? parent.width : 0
    height: mainRow.height + detail.height

    readonly property string subtitle: {
        if (busy)
            return device.pairing ? "Koppelt…" : (device.state === BluetoothDeviceState.Disconnecting ? "Trennt…" : "Verbindet…");
        if (connected)
            return "Verbunden";
        if (root.available)
            return "Tippen zum Koppeln";
        return "Gekoppelt";
    }

    // ---- main row ----
    Item {
        id: mainRow
        width: parent.width
        height: 44

        LauncherDelegateBg {
            active: root.connected
            hovered: hitHover.hovered
            pressed: hitTap.pressed
        }

        TintedIcon {
            id: glyph
            source: "../icons/" + BtUtils.iconAsset(root.device ? root.device.icon : "", root.devName)
            size: 19
            color: Colors.textColor
            anchors.left: parent.left
            anchors.leftMargin: Spacing.spacing8
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.left: glyph.right
            anchors.leftMargin: Spacing.spacing8
            anchors.right: trailing.left
            anchors.rightMargin: Spacing.spacing8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Label {
                width: parent.width
                text: root.devName
                font.weight: root.connected ? Font.Bold : Typography.weightNormal
                elide: Text.ElideRight
            }
            Label {
                width: parent.width
                text: root.subtitle
                font.pixelSize: Typography.fontSize12
                font.weight: Font.Normal
                color: Colors.textColorMuted
                elide: Text.ElideRight
            }
        }

        Row {
            id: trailing
            anchors.right: parent.right
            anchors.rightMargin: Spacing.spacing8
            anchors.verticalCenter: parent.verticalCenter
            spacing: Spacing.spacing6

            // Battery pill: red under 20 %, amber under 40 %, else paper.
            Rectangle {
                visible: root.battery >= 0 && !root.busy
                anchors.verticalCenter: parent.verticalCenter
                height: 18
                width: battLabel.implicitWidth + Spacing.spacing8
                radius: Shape.pill(height)
                color: root.battery < 20 ? Colors.batteryCritical : root.battery < 40 ? Colors.batteryWarning : Colors.pillBackground
                border.width: Shape.thinBorderWidth
                border.color: Colors.pillBorder
                Label {
                    id: battLabel
                    anchors.centerIn: parent
                    text: root.battery + "%"
                    font.pixelSize: Typography.fontSize12
                    font.weight: Font.Bold
                    color: Colors.textColor
                }
            }

            TintedIcon {
                id: rowSpinner
                source: "../icons/icons8-spinner.svg"
                size: Typography.fontSize14
                color: Colors.textColorMuted
                visible: root.busy
                anchors.verticalCenter: parent.verticalCenter
                NumberAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    running: rowSpinner.visible
                    easing.type: Easing.Linear
                }
            }

            TintedIcon {
                source: "../icons/icons8-done.svg"
                size: Typography.fontSize14
                color: Colors.textColor
                visible: root.connected && !root.busy
                anchors.verticalCenter: parent.verticalCenter
            }

            TintedIcon {
                source: "../icons/icons8-lock.svg"
                size: Typography.fontSize12
                color: Colors.textColorMuted
                visible: root.blocked && !root.busy
                anchors.verticalCenter: parent.verticalCenter
            }

            ExpandArrow {
                visible: root.hasDetail
                expanded: root.expanded
                collapsedRotation: 0
                expandedRotation: 180
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Connect / pair hit area: left of the chevron.
        Item {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: root.hasDetail ? trailing.left : parent.right
            HoverHandler {
                id: hitHover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                id: hitTap
                onTapped: root.activated()
            }
        }

        // Chevron area toggles the detail panel.
        Item {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.hasDetail ? 34 : 0
            visible: root.hasDetail
            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: root.detailToggled()
            }
        }
    }

    // ---- detail panel ----
    ExpandSection {
        id: detail
        expanded: root.expanded && root.hasDetail
        anchors.top: mainRow.bottom
        width: parent.width

        Column {
            width: parent.width
            leftPadding: Spacing.spacing8
            rightPadding: Spacing.spacing8
            bottomPadding: Spacing.spacing8
            spacing: Spacing.spacing6

            // Battery bar (only when reported).
            Row {
                visible: root.battery >= 0
                width: parent.width - Spacing.spacing8 * 2
                spacing: Spacing.spacing8

                Rectangle {
                    id: battTrack
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - battPct.width - parent.spacing
                    height: 14
                    radius: Shape.pill(height)
                    color: Colors.progressBackground
                    border.width: Shape.thinBorderWidth
                    border.color: Colors.pillBorder
                    clip: true
                    Rectangle {
                        height: parent.height
                        width: Math.max(0, Math.min(1, root.battery / 100)) * parent.width
                        radius: parent.radius
                        color: root.battery < 20 ? Colors.batteryCritical : Colors.accentColor
                    }
                }
                Label {
                    id: battPct
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.battery + "%"
                    font.pixelSize: Typography.fontSize12
                    font.weight: Font.Bold
                }
            }

            // Facts.
            Grid {
                columns: 2
                columnSpacing: Spacing.spacing8
                rowSpacing: 2

                Label {
                    text: "Typ"
                    font.pixelSize: Typography.fontSize12
                    font.weight: Font.Normal
                    color: Colors.textColorMuted
                }
                Label {
                    text: BtUtils.typeLabel(root.device ? root.device.icon : "", root.devName)
                    font.pixelSize: Typography.fontSize12
                }
                Label {
                    text: "Adresse"
                    font.pixelSize: Typography.fontSize12
                    font.weight: Font.Normal
                    color: Colors.textColorMuted
                }
                Label {
                    text: root.device ? root.device.address : "-"
                    font.pixelSize: Typography.fontSize12
                }
            }

            // Action chips.
            Flow {
                width: parent.width - Spacing.spacing8 * 2
                spacing: Spacing.spacing6

                NetChip {
                    text: root.connected ? "Trennen" : "Verbinden"
                    active: root.connected
                    onClicked: root.activated()
                }
                NetChip {
                    text: "Umbenennen"
                    onClicked: root.renameRequested()
                }
                NetChip {
                    text: "Vergessen"
                    danger: true
                    iconSource: "../icons/icons8-trash.svg"
                    onClicked: BluetoothService.forgetDevice(root.device)
                }
            }

            // Trust (drives silent auto-reconnect; BlueZ has no separate flag).
            Row {
                width: parent.width - Spacing.spacing8 * 2
                spacing: Spacing.spacing8
                Label {
                    text: "Vertrauen (auto-verbinden)"
                    font.pixelSize: Typography.fontSize12
                    font.weight: Font.Normal
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - trustToggle.width - parent.spacing
                    elide: Text.ElideRight
                }
                NetToggle {
                    id: trustToggle
                    checked: root.device ? root.device.trusted : false
                    anchors.verticalCenter: parent.verticalCenter
                    onToggled: BluetoothService.setTrusted(root.device, !root.device.trusted)
                }
            }
            Row {
                width: parent.width - Spacing.spacing8 * 2
                spacing: Spacing.spacing8
                Label {
                    text: "Blockieren"
                    font.pixelSize: Typography.fontSize12
                    font.weight: Font.Normal
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - blockToggle.width - parent.spacing
                    elide: Text.ElideRight
                }
                NetToggle {
                    id: blockToggle
                    checked: root.blocked
                    anchors.verticalCenter: parent.verticalCenter
                    onToggled: BluetoothService.setBlocked(root.device, !root.device.blocked)
                }
            }
        }
    }
}

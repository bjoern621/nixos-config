pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import "../"
import "../base"
import "../animations"
import "NetworkUtils.js" as NetworkUtils

// One wifi network row: signal, name, state, plus an expandable management
// panel (connect/disconnect, forget, auto-connect, QR). The menu owns
// connect/password decisions; the row only reports intent.
Item {
    id: root

    required property var network
    property bool expanded: false

    // Menu decides connect vs disconnect vs password prompt.
    signal activated
    signal detailToggled

    readonly property string ssid: network.ssid
    readonly property bool active: network.active
    readonly property bool saved: network.saved
    readonly property bool busy: NetworkService.busyKey === ("wifi:" + ssid)
    readonly property bool hasDetail: saved || active
    // Wifi facts come from the wifi device, never from whichever link nmcli
    // listed first: ethernet is routinely up at the same time.
    readonly property var wifiDetail: NetworkService.detailFor(NetworkService.wifiDevice)

    width: parent ? parent.width : 0
    height: mainRow.height + detail.height

    readonly property string subtitle: {
        if (active) {
            const ip = root.wifiDetail.ip4;
            const addr = ip.length ? ip.split("/")[0] : "Verbunden";
            return addr + " · " + NetworkService.throughputText(NetworkService.wifiDevice);
        }
        if (saved)
            return network.secured ? "Gespeichert · " + network.securityLabel : "Gespeichert";
        return network.securityLabel;
    }

    // ---- main row ----
    Item {
        id: mainRow
        width: parent.width
        height: 40

        LauncherDelegateBg {
            active: root.active
            hovered: hitHover.hovered
            pressed: hitTap.pressed
        }

        SignalBars {
            id: bars
            level: root.network.level
            barHeight: 16
            anchors.left: parent.left
            anchors.leftMargin: Spacing.spacing8
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.left: bars.right
            anchors.leftMargin: Spacing.spacing8
            anchors.right: trailing.left
            anchors.rightMargin: Spacing.spacing8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Label {
                width: parent.width
                text: root.ssid
                font.weight: root.active ? Font.Bold : Typography.weightNormal
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
                visible: root.active && !root.busy
                anchors.verticalCenter: parent.verticalCenter
            }

            TintedIcon {
                source: "../icons/icons8-lock.svg"
                size: Typography.fontSize12
                color: Colors.textColorMuted
                visible: root.network.secured && !root.active && !root.busy
                anchors.verticalCenter: parent.verticalCenter
            }

            MiniIconButton {
                visible: root.hasDetail
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.detailToggled()

                ExpandArrow {
                    anchors.centerIn: parent
                    expanded: root.expanded
                    collapsedRotation: 0
                    expandedRotation: 180
                }
            }
        }

        // Connect/disconnect hit area: left of the chevron button.
        Item {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: trailing.left
            HoverHandler {
                id: hitHover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                id: hitTap
                onTapped: root.activated()
            }
        }
    }

    // ---- detail panel ----
    ExpandSection {
        id: detail
        expanded: root.expanded
        anchors.top: mainRow.bottom
        width: parent.width

        Column {
            width: parent.width
            leftPadding: Spacing.spacing8
            rightPadding: Spacing.spacing8
            bottomPadding: Spacing.spacing8
            spacing: Spacing.spacing6

            // Connection facts (active only).
            DeviceFacts {
                visible: root.active
                width: parent.width - Spacing.spacing8 * 2
                rows: root.active ? NetworkUtils.deviceDetailRows(root.wifiDetail) : []
            }

            // Action chips.
            Flow {
                width: parent.width - Spacing.spacing8 * 2
                spacing: Spacing.spacing6

                NetChip {
                    text: root.active ? "Trennen" : "Verbinden"
                    onClicked: root.activated()
                }
                NetChip {
                    visible: root.active
                    text: "QR-Code"
                    onClicked: NetworkService.requestQr(root.network.savedUuid, root.ssid)
                }
                NetChip {
                    visible: root.saved
                    text: "Vergessen"
                    danger: true
                    iconSource: "../icons/icons8-trash.svg"
                    onClicked: NetworkService.forget(root.network.savedUuid, root.ssid)
                }
            }

            // Saved-network toggles.
            Row {
                visible: root.saved
                width: parent.width - Spacing.spacing8 * 2
                spacing: Spacing.spacing8
                Label {
                    text: "Automatisch verbinden"
                    font.pixelSize: Typography.fontSize12
                    font.weight: Font.Normal
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - autoToggle.width - parent.spacing
                    elide: Text.ElideRight
                }
                NetToggle {
                    id: autoToggle
                    checked: root.network.autoconnect
                    anchors.verticalCenter: parent.verticalCenter
                    onToggled: NetworkService.setAutoconnect(root.network.savedUuid, !root.network.autoconnect)
                }
            }
            // QR image (active row, once generated).
            Image {
                visible: root.active && NetworkService.qrImagePath.length > 0
                source: NetworkService.qrImagePath
                cache: false
                width: 120
                height: 120
                fillMode: Image.PreserveAspectFit
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}

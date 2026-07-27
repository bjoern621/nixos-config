pragma ComponentBehavior: Bound

import QtQuick
import "../"
import "../base"
import "../animations"
import "NetworkUtils.js" as NetworkUtils

// One wired device row: link state, address, throughput, plus an expandable
// facts panel and connect/disconnect.
// Unlike a wifi row the whole row toggles the panel instead of connecting: a
// wired link comes up by itself, so reading it is the common intent and a stray
// click must not drop the connection.
Item {
    id: root

    required property var wired   // NetworkUtils.buildWiredModel entry
    property bool expanded: false

    signal detailToggled

    readonly property bool busy: NetworkService.busyKey === ("eth:" + wired.device) || wired.busy

    width: parent ? parent.width : 0
    height: mainRow.height + detail.height

    readonly property string subtitle: {
        if (root.wired.connected) {
            const ip = root.wired.detail.ip4;
            const addr = ip.length ? ip.split("/")[0] : "Verbunden";
            return addr + " · " + NetworkService.throughputText(root.wired.device);
        }
        return root.wired.stateLabel;
    }

    // ---- main row ----
    Item {
        id: mainRow
        width: parent.width
        height: 40

        LauncherDelegateBg {
            active: root.wired.connected
            hovered: hitHover.hovered
            pressed: hitTap.pressed
        }

        NetworkGlyph {
            id: glyph
            width: 18
            height: 18
            mode: "ethernet"
            color: root.wired.connected ? Colors.textColor : Colors.textColorMuted
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
                text: root.wired.name
                font.weight: root.wired.connected ? Font.Bold : Typography.weightNormal
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
                visible: root.wired.connected && !root.busy
                anchors.verticalCenter: parent.verticalCenter
            }

            MiniIconButton {
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
                onTapped: root.detailToggled()
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

            DeviceFacts {
                width: parent.width - Spacing.spacing8 * 2
                rows: NetworkUtils.deviceDetailRows(root.wired.detail)
            }

            Flow {
                width: parent.width - Spacing.spacing8 * 2
                spacing: Spacing.spacing6

                NetChip {
                    // No carrier: nothing to activate, so neither chip applies.
                    visible: root.wired.plugged
                    text: root.wired.connected ? "Trennen" : "Verbinden"
                    active: !root.wired.connected
                    onClicked: {
                        if (root.wired.connected)
                            NetworkService.wiredDisconnect(root.wired.device);
                        else
                            NetworkService.wiredConnect(root.wired.device);
                    }
                }
            }
        }
    }
}

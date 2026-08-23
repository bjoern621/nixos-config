pragma ComponentBehavior: Bound

import QtQuick
import "../"
import "../base"

// VPN/WireGuard/tunnel row: one switch per tunnel. NM profiles go through nmcli
// con up/down; Tailscale and WireGuard-over-wstunnel each carry a flag routing to
// their own toggle.
Item {
    id: root

    required property var vpn   // { name, uuid, kind, active }

    readonly property bool busy: NetworkService.busyKey === ("vpn:" + vpn.uuid)

    width: parent ? parent.width : 0
    height: 40

    LauncherDelegateBg {
        active: root.vpn.active
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: Spacing.spacing8
        anchors.right: toggle.left
        anchors.rightMargin: Spacing.spacing8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Label {
            width: parent.width
            text: root.vpn.name
            font.weight: root.vpn.active ? Font.Bold : Typography.weightNormal
            elide: Text.ElideRight
        }
        Label {
            width: parent.width
            text: root.vpn.active ? root.vpn.kind + " · aktiv" : root.vpn.kind
            font.pixelSize: Typography.fontSize12
            font.weight: Font.Normal
            color: Colors.textColorMuted
            elide: Text.ElideRight
        }
    }

    NetToggle {
        id: toggle
        anchors.right: parent.right
        anchors.rightMargin: Spacing.spacing8
        anchors.verticalCenter: parent.verticalCenter
        checked: root.vpn.active
        busy: root.busy
        onToggled: {
            if (root.vpn.tailscale)
                NetworkService.setTailscale(!root.vpn.active);
            else if (root.vpn.wgWstunnel)
                NetworkService.setWgWstunnel(!root.vpn.active);
            else if (root.vpn.active)
                NetworkService.vpnDown(root.vpn.uuid);
            else
                NetworkService.vpnUp(root.vpn.uuid);
        }
    }
}

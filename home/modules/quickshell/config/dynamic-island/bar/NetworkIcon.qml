import QtQuick
import "../"
import "../base"
import "../animations"

// Bar network indicator: wifi/ethernet/off glyph, plus a VPN shield to its right
// while a tunnel is active. State comes from the NetworkService singleton.
Row {
    id: root

    anchors.verticalCenter: parent.verticalCenter
    spacing: Spacing.spacing4

    Item {
        width: 18
        height: 18
        anchors.verticalCenter: parent.verticalCenter

        ContentReplace {
            id: iconReplace
            contentKey: NetworkService.iconMode + ":" + NetworkService.iconLevel
            anchors.fill: parent

            NetworkGlyph {
                anchors.fill: parent
                mode: NetworkService.iconMode
                level: NetworkService.iconLevel
                color: Colors.textColor
            }
        }
    }

    // VPN active: shield glyph right of the network icon.
    VpnGlyph {
        width: 14
        height: 14
        anchors.verticalCenter: parent.verticalCenter
        visible: NetworkService.vpnActive
    }
}

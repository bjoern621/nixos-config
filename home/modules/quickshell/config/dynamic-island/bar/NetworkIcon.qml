import QtQuick
import "../"
import "../base"
import "../animations"

// Bar network indicator: wifi/ethernet/off glyph with a VPN badge overlay.
// State comes from the NetworkService singleton, matching VolumeIcon's shape.
Item {
    id: root

    anchors.verticalCenter: parent.verticalCenter
    width: 18
    height: 18

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

    // VPN active: small accent chip in the top-right corner.
    Rectangle {
        visible: NetworkService.vpnActive
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

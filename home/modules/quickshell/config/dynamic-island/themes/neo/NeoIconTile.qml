import QtQuick
import "../../"

// Bordered icon frame: cream tile, ink border, icon or first-letter fallback.
Rectangle {
    id: root

    property url source
    property string fallback: "?"

    width: 28
    height: 28
    radius: 5
    color: NeoTokens.paper
    border.width: NeoTokens.thinBorderWidth
    border.color: NeoTokens.ink

    Image {
        id: icon
        anchors.centerIn: parent
        width: parent.width - 10
        height: parent.height - 10
        source: root.source
        sourceSize: Qt.size(width, width)
    }

    Text {
        anchors.centerIn: parent
        visible: icon.status !== Image.Ready
        text: root.fallback
        color: NeoTokens.ink
        font.family: Typography.fontFamily
        font.pixelSize: Typography.fontSize12
        font.weight: Font.Black
    }
}

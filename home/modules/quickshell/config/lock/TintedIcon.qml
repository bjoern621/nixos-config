import QtQuick
import QtQuick.Effects
import "."

Item {
    id: root

    property url source
    property int size: 18
    property color color: Colors.textColor
    property real sourceScale: 2.0

    width: size
    height: size

    Image {
        id: iconImage
        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(Math.round(root.width * root.sourceScale), Math.round(root.height * root.sourceScale))
        fillMode: Image.PreserveAspectFit
        smooth: true
        antialiasing: true
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: iconImage
        source: iconImage
        colorization: 1.0
        colorizationColor: root.color
    }
}

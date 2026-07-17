import QtQuick
import "../"
import "../base"
import "../animations"

Item {
    id: root

    anchors.verticalCenter: parent.verticalCenter
    width: Typography.fontSize16
    height: Typography.fontSize16

    ContentReplace {
        id: volIconReplace
        contentKey: VolumeService.iconSource
        anchors.fill: parent

        Item {
            id: volIcon
            x: 0
            y: 0
            width: Typography.fontSize16
            height: Typography.fontSize16

            TintedIcon {
                anchors.centerIn: parent
                size: Typography.fontSize16
                source: volIconReplace.displayValue
            }
        }
    }
}

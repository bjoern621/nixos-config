import Quickshell.Services.SystemTray
import QtQuick

Row {
    spacing: 8
    anchors.verticalCenter: parent.verticalCenter

    Repeater {
        model: SystemTray.items

        Rectangle {
            width: 20
            height: 20
            color: "transparent"
            anchors.verticalCenter: parent.verticalCenter

            Image {
                source: modelData.icon
                width: 16
                height: 16
                anchors.centerIn: parent
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function(mouse) {
                    if (mouse.button === Qt.LeftButton) {
                        modelData.activate()
                    } else {
                        modelData.showMenu()
                    }
                }
            }
        }
    }
}

import Quickshell
import QtQuick

ShellRoot {
    PanelWindow {
        id: root

        anchors {
            top: true
            left: true
            right: true
        }

        exclusiveZone: 0
        color: "transparent"

        implicitHeight: 36

        property bool isHovered: false

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onContainsMouseChanged: {
                if (containsMouse) {
                    root.isHovered = true
                    slideIn.start()
                } else {
                    root.isHovered = false
                    slideOut.start()
                }
            }
        }

        NumberAnimation {
            id: slideIn
            target: pill
            property: "y"
            from: -pill.implicitHeight - 8
            to: 4
            duration: 200
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: slideOut
            target: pill
            property: "y"
            from: 4
            to: -pill.implicitHeight - 8
            duration: 200
            easing.type: Easing.OutCubic
        }

        Rectangle {
            id: pill
            x: (root.width - implicitWidth) / 2
            y: -implicitHeight - 8

            implicitWidth: contentRow.implicitWidth + 24
            implicitHeight: 32

            radius: implicitHeight / 2
            color: Colors.pillBackground

            border.width: 1
            border.color: Colors.pillBorder

            Row {
                id: contentRow
                anchors.centerIn: parent
                spacing: 8

                WorkspaceIndicator {}

                Rectangle {
                    width: 1
                    height: 16
                    color: Colors.separatorColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                SystemTray {}

                Rectangle {
                    width: 1
                    height: 16
                    color: Colors.separatorColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                DateTime {}

                Rectangle {
                    width: 1
                    height: 16
                    color: Colors.separatorColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                VolumeIcon {}

                Rectangle {
                    width: 1
                    height: 16
                    color: Colors.separatorColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                Battery {}

            }
        }
    }

    VolumeOsd {}
    BrightnessOsd {}
}

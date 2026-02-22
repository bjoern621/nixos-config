import Quickshell
import QtQuick

PanelWindow {
    id: root

    anchors {
        top: true
    }

    margins {
        top: 8
    }

    exclusiveZone: 34
    color: "transparent"

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    Rectangle {
        id: pill
        anchors.centerIn: parent

        implicitWidth: label.implicitWidth + 48
        implicitHeight: 34

        radius: implicitHeight / 2
        color: "#111111"

        Text {
            id: label
            anchors.centerIn: parent

            text: "Dynamic Island"
            color: "#ffffff"
            font.pixelSize: 13
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
        }
    }
}

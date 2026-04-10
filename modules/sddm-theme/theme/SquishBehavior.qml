import QtQuick

Behavior {
    id: root

    property bool bouncy: false
    property int duration: 100

    NumberAnimation {
        duration: root.duration
        easing.type: root.bouncy ? Easing.OutBack : Easing.OutCubic
    }
}

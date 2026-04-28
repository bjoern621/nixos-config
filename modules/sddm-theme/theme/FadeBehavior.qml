import QtQuick

Behavior {
    id: root

    property int duration: 80
    property int easing: Easing.OutCubic

    NumberAnimation {
        duration: root.duration
        easing.type: root.easing
    }
}

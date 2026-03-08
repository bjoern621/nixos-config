import QtQuick

Item {
    id: root

    default property alias content: contentContainer.data

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: tapHandler.pressed

    signal clicked()

    implicitWidth: contentContainer.childrenRect.width + Spacing.spacing12
    implicitHeight: 28

    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    Rectangle {
        id: background
        anchors.fill: parent
        radius: height / 2
        color: root.pressed ? Colors.hoverItemPressed
             : root.hovered ? Colors.hoverItemHovered
             : "transparent"

        // DEBUG
        // border.width: 1
        // border.color: "red"

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    Item {
        id: contentContainer
        anchors.centerIn: parent
        width: childrenRect.width
        height: parent.height

        // DEBUG
        // Rectangle {
        //     anchors.fill: parent
        //     color: "transparent"
        //     border.width: 1
        //     border.color: "blue"
        // }
    }

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tapHandler
        onTapped: root.clicked()
    }
}

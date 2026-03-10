import QtQuick

Item {
    id: root

    default property alias content: contentContainer.data
    property HoverMenu menu: null

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: tapHandler.pressed
    readonly property bool menuOpen: internal.menuOpen
    readonly property real menuHeight: internal.effectiveMenuHeight

    signal clicked()
    signal menuClosed()

    implicitWidth: contentContainer.childrenRect.width + Spacing.spacing12
    implicitHeight: 28

    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    QtObject {
        id: internal
        property bool menuOpen: false
        property real effectiveMenuHeight: 0
        readonly property bool shouldShow: root.menu !== null && (root.hovered || (root.menu && root.menu.keepOpen))

        onShouldShowChanged: {
            if (shouldShow) {
                menuHideTimer.stop()
                if (!menuOpen) {
                    menuShowTimer.restart()
                }
            } else {
                menuShowTimer.stop()
                menuHideTimer.restart()
            }
        }
    }

    Timer {
        id: menuShowTimer
        interval: 250
        onTriggered: {
            internal.menuOpen = true
            internal.effectiveMenuHeight = root.menu ? root.menu.implicitHeight : 0
            root.menu.show()
        }
    }

    Timer {
        id: menuHideTimer
        interval: 200
        onTriggered: {
            internal.menuOpen = false
            if (root.menu) root.menu.hide()
        }
    }

    Connections {
        target: root.menu
        enabled: root.menu !== null
        function onHidden() {
            internal.effectiveMenuHeight = 0
            root.menuClosed()
        }
    }

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

import QtQuick
import "../"

Item {
    id: root

    default property alias content: contentContainer.data
    property HoverMenu menu: null
    property bool clickable: true
    property bool menuOnClick: false
    property real pressedScale: 0.85

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: tapHandler.pressed
    readonly property bool popupOpen: internal.menuOpen
    readonly property Item popupItem: menu

    signal clicked
    signal menuClosed

    implicitWidth: contentContainer.childrenRect.width + Spacing.spacing12
    implicitHeight: 28

    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    QtObject {
        id: internal
        property bool menuOpen: false
        property bool clickArmed: false
        readonly property bool shouldShow: root.menu !== null && (root.menuOnClick ? (clickArmed && (root.hovered || (root.menu && root.menu.keepOpen))) : (root.hovered || (root.menu && root.menu.keepOpen)))

        onShouldShowChanged: {
            if (shouldShow) {
                menuHideTimer.stop();
                if (!menuOpen) {
                    if (root.menuOnClick) {
                        internal.menuOpen = true;
                        root.menu.show();
                    } else {
                        menuShowTimer.restart();
                    }
                }
            } else {
                menuShowTimer.stop();
                menuHideTimer.restart();
            }
        }
    }

    Timer {
        id: menuShowTimer
        interval: 150
        onTriggered: {
            internal.menuOpen = true;
            root.menu.show();
        }
    }

    Timer {
        id: menuHideTimer
        interval: 100
        onTriggered: {
            internal.menuOpen = false;
            if (root.menu)
                root.menu.hide();
        }
    }

    Connections {
        target: root.menu
        enabled: root.menu !== null
        function onHidden() {
            internal.menuOpen = false;
            if (root.menuOnClick)
                internal.clickArmed = false;
            root.menuClosed();
        }
    }

    scale: root.clickable && tapHandler.pressed ? root.pressedScale : 1.0
    SquishBehavior on scale {}

    Rectangle {
        id: background
        anchors.fill: parent
        radius: height / 2
        color: root.clickable && root.pressed ? Colors.hoverItemPressed : root.hovered ? Colors.hoverItemHovered : "transparent"
        border.color: root.hovered || (root.clickable && root.pressed) ? Colors.pillBorder : "transparent"
    }

    Item {
        id: contentContainer
        anchors.centerIn: parent
        width: Math.max(0, root.width - Spacing.spacing12)
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
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        id: tapHandler
        enabled: root.clickable
        onTapped: {
            root.clicked();

            if (root.menuOnClick && root.menu) {
                if (internal.menuOpen) {
                    internal.clickArmed = false;
                    menuShowTimer.stop();
                    menuHideTimer.restart();
                } else {
                    internal.clickArmed = true;
                    menuHideTimer.stop();
                    internal.menuOpen = true;
                    root.menu.show();
                }
            }
        }
    }
}

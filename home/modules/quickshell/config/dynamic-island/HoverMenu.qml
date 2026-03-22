import QtQuick

PopReveal {
    id: menuWrapper

    default property alias content: contentArea.data
    property int gapHeight: 4
    property bool contentInteracting: false

    readonly property bool menuHovered: hoverHandler.hovered
    readonly property bool keepOpen: menuHovered || contentInteracting

    implicitHeight: contentArea.childrenRect.height + gapHeight

    HoverHandler {
        id: hoverHandler
    }

    Item {
        id: contentArea
        y: menuWrapper.gapHeight
        width: menuWrapper.width
        height: childrenRect.height
    }
}

import QtQuick
import "../"

PopReveal {
    id: menuWrapper

    default property alias content: contentArea.data
    property int gapHeight: Spacing.spacing4
    property bool contentInteracting: false

    readonly property bool menuHovered: hoverHandler.hovered
    readonly property bool keepOpen: menuHovered || contentInteracting

    // The one view a wrapper holds.
    // Named so the size below reads a declared implicit size,
    // rather than measuring what the layout settled on.
    readonly property Item view: contentArea.children.length > 0 ? contentArea.children[0] : null

    // childrenRect answers a layout pass late,
    // and this wrapper's bottom edge sits flush with the view's,
    // so a late answer is a dead strip along the bottom of the hover area
    // and of the Bar's input mask.
    implicitWidth: menuWrapper.view ? menuWrapper.view.implicitWidth : 0
    implicitHeight: (menuWrapper.view ? menuWrapper.view.implicitHeight : 0) + gapHeight

    HoverHandler {
        id: hoverHandler
    }

    Item {
        id: contentArea
        y: menuWrapper.gapHeight
        width: menuWrapper.width
        height: menuWrapper.view ? menuWrapper.view.implicitHeight : 0
    }
}

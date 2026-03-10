import QtQuick

Item {
    id: menuWrapper

    default property alias content: contentArea.data
    property int gapHeight: 4
    property bool contentInteracting: false

    readonly property bool menuHovered: hoverHandler.hovered
    readonly property bool keepOpen: menuHovered || contentInteracting

    signal hidden()

    implicitHeight: contentArea.childrenRect.height + gapHeight
    opacity: 0
    visible: opacity > 0

    HoverHandler {
        id: hoverHandler
    }

    Item {
        id: contentArea
        y: menuWrapper.gapHeight
        width: menuWrapper.width
        height: childrenRect.height
    }

    NumberAnimation {
        id: showAnim
        target: menuWrapper
        property: "opacity"
        to: 1
        duration: 150
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: hideAnim
        target: menuWrapper
        property: "opacity"
        to: 0
        duration: 150
        easing.type: Easing.InCubic
        onStopped: menuWrapper.hidden()
    }

    function show() {
        hideAnim.stop()
        showAnim.start()
    }

    function hide() {
        showAnim.stop()
        hideAnim.start()
    }
}

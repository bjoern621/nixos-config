import QtQuick

Item {
    id: menuWrapper

    default property alias content: contentArea.data
    property int gapHeight: 4
    property bool contentInteracting: false

    readonly property bool menuHovered: hoverHandler.hovered
    readonly property bool keepOpen: menuHovered || contentInteracting

    signal hidden()

    readonly property real _slideOffset: Spacing.spacing8

    implicitHeight: contentArea.childrenRect.height + gapHeight
    opacity: 0
    visible: opacity > 0

    transform: Translate {
        id: slideTransform
        y: -menuWrapper._slideOffset
    }

    HoverHandler {
        id: hoverHandler
    }

    Item {
        id: contentArea
        y: menuWrapper.gapHeight
        width: menuWrapper.width
        height: childrenRect.height
    }

    ParallelAnimation {
        id: showAnim
        NumberAnimation { target: menuWrapper; property: "opacity"; to: 1; duration: 150; easing.type: Easing.OutCubic }
        NumberAnimation { target: slideTransform; property: "y"; to: 0; duration: 150; easing.type: Easing.OutCubic }
    }

    ParallelAnimation {
        id: hideAnim
        NumberAnimation { target: menuWrapper; property: "opacity"; to: 0; duration: 150; easing.type: Easing.InCubic }
        NumberAnimation { target: slideTransform; property: "y"; to: -menuWrapper._slideOffset; duration: 150; easing.type: Easing.InCubic }
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

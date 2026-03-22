import QtQuick

Item {
    id: root

    default property alias content: contentArea.data

    property real slideOffset: 40
    property int fadeOutDuration: 120
    property int slideInDuration: 300
    property int fadeInDuration: 200

    signal readyToSwap(int direction)

    clip: true
    implicitWidth: contentArea.childrenRect.width
    implicitHeight: contentArea.childrenRect.height

    property int _direction: 0

    Item {
        id: contentArea
        width: root.width
        height: root.height
    }

    ParallelAnimation {
        id: fadeOutAnim
        NumberAnimation {
            id: fadeOutSlide
            target: contentArea
            property: "x"
            duration: root.fadeOutDuration
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: contentArea
            property: "opacity"
            to: 0
            duration: root.fadeOutDuration
            easing.type: Easing.InCubic
        }
        onFinished: root.readyToSwap(root._direction)
    }

    ParallelAnimation {
        id: slideInAnim
        NumberAnimation {
            target: contentArea
            property: "x"
            to: 0
            duration: root.slideInDuration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: contentArea
            property: "opacity"
            to: 1
            duration: root.fadeInDuration
            easing.type: Easing.OutCubic
        }
    }

    function transition(direction) {
        slideInAnim.stop()
        fadeOutAnim.stop()
        root._direction = direction
        fadeOutSlide.to = -direction * (root.slideOffset / 2)
        fadeOutAnim.start()
    }

    function completeTransition() {
        contentArea.x = root._direction * root.slideOffset
        slideInAnim.start()
    }
}

import QtQuick

Item {
    id: root

    property real slideOffset: Spacing.spacing8
    property int showDuration: 80
    property int hideDuration: 80
    property bool showing: false

    // Qt.TopEdge / BottomEdge / LeftEdge / RightEdge — combinable for diagonals
    // e.g. Qt.TopEdge | Qt.RightEdge = slide from top-right
    property int edge: Qt.TopEdge

    property int transformOriginValue: {
        const t = edge & Qt.TopEdge, b = edge & Qt.BottomEdge;
        const l = edge & Qt.LeftEdge, r = edge & Qt.RightEdge;
        if (t && l) return Item.TopLeft;
        if (t && r) return Item.TopRight;
        if (b && l) return Item.BottomLeft;
        if (b && r) return Item.BottomRight;
        if (t) return Item.Top;
        if (b) return Item.Bottom;
        if (l) return Item.Left;
        if (r) return Item.Right;
        return Item.Center;
    }

    readonly property real _startX: (edge & Qt.LeftEdge) ? -slideOffset : (edge & Qt.RightEdge) ? slideOffset : 0
    readonly property real _startY: (edge & Qt.TopEdge) ? -slideOffset : (edge & Qt.BottomEdge) ? slideOffset : 0

    signal shown
    signal hidden

    opacity: 0
    visible: opacity > 0
    scale: 0.96
    transformOrigin: root.transformOriginValue

    transform: Translate {
        id: slideTransform
        x: root._startX
        y: root._startY
    }

    ParallelAnimation {
        id: showAnim
        NumberAnimation {
            target: root
            property: "opacity"
            to: 1
            duration: root.showDuration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: slideTransform
            property: "x"
            to: 0
            duration: root.showDuration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: slideTransform
            property: "y"
            to: 0
            duration: root.showDuration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "scale"
            to: 1.0
            duration: root.showDuration + 50
            easing.type: Easing.OutBack
        }
        onFinished: root.shown()
    }

    ParallelAnimation {
        id: hideAnim
        NumberAnimation {
            target: root
            property: "opacity"
            to: 0
            duration: root.hideDuration
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: slideTransform
            property: "x"
            to: root._startX
            duration: root.hideDuration
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: slideTransform
            property: "y"
            to: root._startY
            duration: root.hideDuration
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: root
            property: "scale"
            to: 0.96
            duration: root.hideDuration
            easing.type: Easing.InCubic
        }
        onFinished: root.hidden()
    }

    onShowingChanged: showing ? show() : hide()

    function show() {
        hideAnim.stop();
        showAnim.start();
    }

    function hide() {
        showAnim.stop();
        hideAnim.start();
    }
}

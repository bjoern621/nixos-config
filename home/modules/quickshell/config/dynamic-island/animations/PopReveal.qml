import QtQuick

// Reveal wrapper.
// The children ride the pop-in, and this Item's own geometry stands still.
// A scale and a slide are transforms, and a transform emits no geometry change,
// so a consumer that samples this rect once (a Wayland input region)
// keeps whatever it read mid-reveal.
Item {
    id: root

    default property alias content: stage.data

    property real slideOffset: Spacing.spacing8
    property int showDuration: 80
    property int hideDuration: 80
    property bool showing: false

    // Qt.TopEdge / BottomEdge / LeftEdge / RightEdge, combinable for diagonals
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

    visible: stage.opacity > 0
    transformOrigin: root.transformOriginValue

    Item {
        id: stage
        anchors.fill: parent
        opacity: 0
        scale: 0.96
        // Follows root.transformOrigin, which a consumer may override.
        transformOrigin: root.transformOrigin

        transform: Translate {
            id: slideTransform
            x: root._startX
            y: root._startY
        }
    }

    ParallelAnimation {
        id: showAnim
        NumberAnimation {
            target: stage
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
            target: stage
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
            target: stage
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
            target: stage
            property: "scale"
            to: 0.96
            duration: root.hideDuration
            easing.type: Easing.InCubic
        }
        onFinished: root.hidden()
    }

    // showing is the single source of truth.
    // show()/hide() write it instead of driving the animations, so both agree.
    // Re-entry is a no-op: hide() on a hidden reveal emits no second hidden().
    // Bind showing or call show()/hide(), never both: an imperative write kills the binding.
    onShowingChanged: {
        if (showing) {
            hideAnim.stop();
            showAnim.start();
        } else {
            showAnim.stop();
            hideAnim.start();
        }
    }

    function show() {
        root.showing = true;
    }

    function hide() {
        root.showing = false;
    }
}

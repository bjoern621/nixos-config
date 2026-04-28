import QtQuick
import "."

Item {
    id: root

    property real slideOffset: Spacing.spacing8
    property int showDuration: 80
    property int hideDuration: 80
    property bool showing: false
    property int transformOriginValue: Item.Top

    signal shown
    signal hidden

    opacity: 0
    visible: opacity > 0
    scale: 0.96
    transformOrigin: root.transformOriginValue

    transform: Translate {
        id: slideTransform
        y: -root.slideOffset
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
            property: "y"
            to: -root.slideOffset
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

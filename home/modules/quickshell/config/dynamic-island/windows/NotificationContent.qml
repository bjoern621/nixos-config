pragma ComponentBehavior: Bound
import QtQuick
import "../"

Item {
    id: root

    property string appName: ""
    property string summary: ""
    property string body: ""
    property int urgency: 1
    property bool expiryAnimationRunning: false
    property bool expiryPaused: false
    property int expiryDuration: 5000

    // Rows of {index, text} as returned by NotificationListener.actionsFor().
    property var actions: []

    signal expired
    signal actionInvoked(int index)

    implicitHeight: textColumn.implicitHeight

    // Fraction of the expiry timeout still left. The stripe renders it, and
    // running out is what expires the notification, so both stay in step while
    // paused.
    property real expiryProgress: 1.0

    Rectangle {
        id: urgencyStripe
        anchors.left: parent.left
        anchors.top: parent.top
        width: 3
        height: root.implicitHeight * root.expiryProgress
        radius: 2
        color: root.urgency === 2 ? Colors.batteryCritical : Colors.textColorMuted
    }

    NumberAnimation on expiryProgress {
        id: expiryAnim
        running: root.expiryAnimationRunning
        // Qt rejects a pause on an animation that is not running.
        paused: root.expiryPaused && expiryAnim.running
        from: 1.0
        to: 0.0
        duration: root.expiryDuration
        easing.type: Easing.Linear
        onFinished: root.expired()
    }

    Column {
        id: textColumn
        anchors {
            left: urgencyStripe.right
            leftMargin: Spacing.spacing8
            right: parent.right
            top: parent.top
        }
        spacing: Spacing.spacing4

        Text {
            text: root.appName
            font.family: Typography.fontFamily
            font.pixelSize: Typography.fontSize12
            font.weight: Font.Normal
            color: Colors.textColorMuted
            width: parent.width
            elide: Text.ElideRight
            visible: text !== ""
        }

        Label {
            text: root.summary
            width: parent.width
            elide: Text.ElideRight
            visible: text !== ""
        }

        Text {
            text: root.body
            font.family: Typography.fontFamily
            font.pixelSize: Typography.fontSize12
            font.weight: Font.Normal
            color: Colors.textColorMuted
            width: parent.width
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            visible: text !== ""
        }

        Row {
            id: actionRow
            spacing: Spacing.spacing8
            topPadding: Spacing.spacing4
            visible: root.actions.length > 0

            Repeater {
                model: root.actions

                delegate: Item {
                    id: actionBtn
                    required property var modelData

                    implicitWidth: actionLabel.implicitWidth + Spacing.spacing12 * 2
                    implicitHeight: 26
                    width: implicitWidth
                    height: implicitHeight

                    scale: actionTap.pressed ? 0.85 : 1.0
                    SquishBehavior on scale {}

                    // Action button bg. Classic round pill, neo cream hover + accent press.
                    ButtonBg {
                        hovered: actionHover.hovered
                        pressed: actionTap.pressed
                    }

                    HoverHandler {
                        id: actionHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    // Takes the exclusive grab so the tap never also reaches the
                    // click handler on the surrounding card.
                    TapHandler {
                        id: actionTap
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.actionInvoked(actionBtn.modelData.index)
                    }

                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        text: actionBtn.modelData.text
                        font.family: Typography.fontFamily
                        font.pixelSize: Typography.fontSize12
                        font.weight: Font.Normal
                        color: Colors.textColor
                    }
                }
            }
        }
    }
}

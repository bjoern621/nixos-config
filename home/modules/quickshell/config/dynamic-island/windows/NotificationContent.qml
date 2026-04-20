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
    property int expiryDuration: 5000

    implicitHeight: textColumn.implicitHeight

    Rectangle {
        id: urgencyStripe
        anchors.left: parent.left
        anchors.top: parent.top
        width: 3
        height: root.implicitHeight
        radius: 2
        color: root.urgency === 2 ? Colors.batteryCritical : Colors.textColorMuted
    }

    NumberAnimation {
        id: expiryAnim
        target: urgencyStripe
        property: "height"
        to: 0
        duration: root.expiryDuration
        easing.type: Easing.Linear
    }

    onImplicitHeightChanged: {
        if (root.expiryAnimationRunning && !expiryAnim.running && root.implicitHeight > 0) {
            expiryAnim.from = root.implicitHeight
            expiryAnim.start()
        }
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
    }
}

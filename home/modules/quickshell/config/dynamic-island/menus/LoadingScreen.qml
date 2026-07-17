import QtQuick
import "../"
import "../base"
import "../animations"

// Fullscreen overlay for a blocking action with nothing to wait on (lock, hibernate).
// Graceful shutdown waits on windows, so it uses ShutdownScreen instead.

PopReveal {
    id: root

    property string actionLabel: ""
    signal cancelled

    // Fullscreen reveal, slower than PopReveal's popup defaults.
    edge: Qt.BottomEdge
    showDuration: 200
    hideDuration: 150
    // Fullscreen dim scales from its middle.
    // Edge-derived origin would drag the whole screen toward one side.
    transformOrigin: Item.Center

    focus: visible

    Keys.onEscapePressed: root.cancelled()

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)

        OverlayExitButton {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Spacing.spacing24
            onTapped: root.cancelled()
        }

        Column {
            anchors.centerIn: parent
            spacing: Spacing.spacing24

            OverlaySpinner {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 60
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.actionLabel
                font.family: Typography.fontFamily
                font.weight: Font.Bold
                font.pixelSize: Typography.fontSize16
                color: Colors.textColor
            }
        }
    }
}

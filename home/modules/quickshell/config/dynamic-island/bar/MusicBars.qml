import QtQuick
import "../"

Row {
    id: root

    property bool playing: false

    spacing: Spacing.spacing2
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    Repeater {
        model: 4

        Rectangle {
            id: bar
            required property int index

            width: 3
            height: Spacing.spacing4
            radius: width / 2
            color: Colors.accentColor
            anchors.verticalCenter: parent.verticalCenter

            readonly property real minHeight: Spacing.spacing4
            readonly property real maxHeight: Spacing.spacing12

            SequentialAnimation on height {
                id: bounceAnim
                running: root.playing
                loops: Animation.Infinite

                NumberAnimation {
                    to: bar.maxHeight * (0.6 + 0.4 * Math.random())
                    duration: 280 + bar.index * 60 + Math.random() * 120
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    to: bar.minHeight + Math.random() * (bar.maxHeight * 0.3)
                    duration: 260 + bar.index * 50 + Math.random() * 100
                    easing.type: Easing.InQuad
                }
            }

            // Reset to min height when paused
            NumberAnimation {
                id: resetAnim
                target: bar
                property: "height"
                to: bar.minHeight
                duration: 150
                easing.type: Easing.OutCubic
            }

            Connections {
                target: root
                function onPlayingChanged() {
                    if (!root.playing) {
                        bounceAnim.stop()
                        resetAnim.start()
                    }
                }
            }
        }
    }
}

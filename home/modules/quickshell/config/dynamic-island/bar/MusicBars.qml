import QtQuick
import "../"

Row {
    id: root

    property bool playing: false
    // Bar keeps its surface mapped while the pill is off screen.
    // Animating then repaints an unseen surface at 60fps for as long as music plays.
    property bool barHidden: false

    readonly property bool animating: root.playing && !root.barHidden

    spacing: Spacing.spacing2
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    Repeater {
        model: 4

        Rectangle {
            id: bar
            required property int index

            width: 3
            radius: width / 2
            color: Colors.accentColor
            anchors.verticalCenter: parent.verticalCenter

            readonly property real minHeight: Spacing.spacing4
            readonly property real maxHeight: Spacing.spacing12

            // Animations drive `wave` (0 = resting, 1 = peak), never `height`.
            // height keeps one writer, and both animations keep a constant `to`.
            // A `to` re-rolled per iteration deadlocks: assigning it from the
            // ScriptAction re-enters the script until the stack overflows, and
            // binding it loops once a second animation targets the same property.
            property real wave: 0
            // Re-rolled while wave sits at 0, where height is minHeight for any peak.
            // A new roll never jumps the bar.
            property real peak: maxHeight

            height: bar.minHeight + (bar.peak - bar.minHeight) * bar.wave

            SequentialAnimation on wave {
                running: root.animating
                loops: Animation.Infinite

                // Re-rolls per iteration.
                // As bindings their only deps are constants, so Math.random() runs
                // once and every bar freezes on one height and one duration.
                ScriptAction {
                    script: {
                        bar.peak = bar.maxHeight * (0.6 + 0.4 * Math.random());
                        riseAnim.duration = 280 + bar.index * 60 + Math.random() * 120;
                    }
                }
                NumberAnimation {
                    id: riseAnim
                    to: 1
                    easing.type: Easing.OutQuad
                }
                ScriptAction {
                    script: fallAnim.duration = 260 + bar.index * 50 + Math.random() * 100
                }
                NumberAnimation {
                    id: fallAnim
                    to: 0
                    easing.type: Easing.InQuad
                }
            }

            // Owns wave whenever the bounce does not. Exclusive via running.
            NumberAnimation on wave {
                running: !root.animating
                to: 0
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
    }
}

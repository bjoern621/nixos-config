import QtQuick
import "../"

Row {
    id: root

    property bool playing: false
    // Bar keeps its surface mapped while the pill is off screen.
    // Animating then repaints an unseen surface for as long as music plays.
    property bool barHidden: false

    readonly property bool animating: root.playing && !root.barHidden

    // Bars step on this timer. A vsync animation would redraw the Bar surface at
    // display rate, and with a popup open that surface spans the screen width.
    readonly property int tickMs: 33

    signal tick

    Timer {
        interval: root.tickMs
        repeat: true
        running: root.animating
        onTriggered: root.tick()
    }

    spacing: Spacing.spacing2
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    Repeater {
        model: 4

        Rectangle {
            id: bar
            required property int index

            width: 3
            radius: Shape.pill(width)
            color: Colors.accentColor
            anchors.verticalCenter: parent.verticalCenter

            readonly property real minHeight: Spacing.spacing4
            readonly property real maxHeight: Spacing.spacing12

            // wave: 0 = resting, 1 = peak. height keeps one writer.
            property real wave: 0
            // Re-rolled per bounce while wave sits at 0, where height is minHeight
            // for any peak, so a new roll never jumps the bar.
            property real peak: maxHeight
            property real rise: 300   // ms, bounce up, eased out
            property real fall: 300   // ms, bounce down, eased in
            property real elapsed: 0

            height: bar.minHeight + (bar.peak - bar.minHeight) * bar.wave

            function roll() {
                bar.peak = bar.maxHeight * (0.6 + 0.4 * Math.random());
                bar.rise = 280 + bar.index * 60 + Math.random() * 120;
                bar.fall = 260 + bar.index * 50 + Math.random() * 100;
                bar.elapsed = 0;
            }

            Component.onCompleted: roll()

            Connections {
                target: root
                function onTick() {
                    bar.elapsed += root.tickMs;
                    if (bar.elapsed < bar.rise) {
                        const p = bar.elapsed / bar.rise;
                        bar.wave = 1 - (1 - p) * (1 - p);
                    } else if (bar.elapsed < bar.rise + bar.fall) {
                        const p = (bar.elapsed - bar.rise) / bar.fall;
                        bar.wave = 1 - p * p;
                    } else {
                        bar.roll();
                        bar.wave = 0;
                    }
                }
            }

            // Settles the bar whenever the bounce stops.
            NumberAnimation on wave {
                running: !root.animating
                to: 0
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
    }
}

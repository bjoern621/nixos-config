import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../"
import "../base"

// Transient OSD: pops the pill on the focused screen, hides after visibleMs.
// Unmapped whenever hidden, per the layer-surface rule in CLAUDE.md.
// Every mapped surface is composited and blurred each frame, on every screen.
PanelWindow {
    id: root

    property alias iconSource: pill.iconSource
    property alias label: pill.label
    property alias value: pill.value
    property alias valueLabel: pill.valueLabel
    property alias mutedLabel: pill.mutedLabel
    property alias muted: pill.muted
    property alias fillColor: pill.fillColor

    readonly property int pillWidth: 200
    readonly property int topOffset: Spacing.spacing40
    readonly property int visibleMs: 2000

    visible: false

    anchors {
        top: true
    }
    exclusiveZone: 0
    color: "transparent"

    // Wider than the pill so the slide-in has room to travel.
    implicitWidth: root.pillWidth + 2 * Spacing.spacing40
    implicitHeight: root.topOffset + pill.implicitHeight + Spacing.spacing16
    // Empty input region: OSD never takes a click.
    mask: Region {}

    // Named showOsd, not show: PanelWindow may define its own show().
    function showOsd() {
        const s = root.focusedScreen();
        if (s)
            root.screen = s;
        root.visible = true;
        hideTimer.restart();
        reveal.show();
    }

    function focusedScreen() {
        const mon = Hyprland.focusedMonitor;
        if (!mon)
            return null;
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === mon.name)
                return screens[i];
        }
        return null;
    }

    Timer {
        id: hideTimer
        interval: root.visibleMs
        onTriggered: reveal.hide()
    }

    PopReveal {
        id: reveal
        x: (root.width - width) / 2
        y: root.topOffset
        width: root.pillWidth
        height: pill.implicitHeight
        showDuration: 120
        hideDuration: 100
        slideOffset: Spacing.spacing16

        onHidden: root.visible = false

        OsdPill {
            id: pill
            anchors.fill: parent
        }
    }
}

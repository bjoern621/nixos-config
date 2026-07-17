pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import "../"
import "../base"

Column {
    id: root

    required property var streamNode
    // Read by the menu to keep itself open during a drag. A property, not a
    // press/release signal: a row destroyed mid-drag emits no release.
    readonly property bool sliderPressed: appSlider.pressed

    width: parent ? parent.width : 0
    spacing: Spacing.spacing4

    readonly property var appAudio: streamNode.audio

    // Apps like Spotify re-assert their own internal volume onto the PipeWire
    // stream on every track change, so a volume set only on the stream node is
    // transient. When the stream maps to an MPRIS player, driving the player's
    // volume updates the app's internal volume; the app then propagates that to
    // the stream and the change persists across tracks. Match the stream to a
    // player by comparing normalized app/dbus identifiers.
    readonly property var mprisPlayer: {
        const players = Mpris.players?.values ?? [];
        if (!players.length)
            return null;
        const props = streamNode.properties ?? {};
        const norm = s => (s ?? "").toString().toLowerCase().replace(/[^a-z0-9]/g, "");
        const streamTokens = [props["application.name"], props["node.name"], props["application.process.binary"], streamNode.name].map(norm).filter(t => t.length >= 3);
        for (let i = 0; i < players.length; i++) {
            const p = players[i];
            if (!p || !p.volumeSupported)
                continue;
            const dbusTail = (p.dbusName ?? "").toString().split(".").pop();
            const playerTokens = [p.desktopEntry, p.identity, dbusTail].map(norm).filter(t => t.length >= 3);
            const hit = streamTokens.some(s => playerTokens.some(pt => s === pt || s.includes(pt) || pt.includes(s)));
            if (hit)
                return p;
        }
        return null;
    }
    readonly property int appVolume: Math.round((appAudio?.volume ?? 0) * 100)
    readonly property bool appMuted: appAudio?.muted ?? false
    readonly property url appIconSource: VolumeService.iconFor(root.appVolume, root.appMuted)

    Item {
        width: parent.width
        height: 24

        Label {
            text: root.streamNode.description || root.streamNode.name
            font.pixelSize: Typography.fontSize12
            elide: Text.ElideRight
            anchors {
                left: parent.left
                right: appMuteButton.left
                rightMargin: Spacing.spacing8
                verticalCenter: parent.verticalCenter
            }
        }

        VolumeMuteButton {
            id: appMuteButton
            width: 24
            height: 24
            iconSize: 16
            iconSource: root.appIconSource
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            onTapped: {
                if (root.appAudio)
                    root.appAudio.muted = !root.appAudio.muted;
            }
        }
    }

    Row {
        width: parent.width
        spacing: Spacing.spacing8

        StepSlider {
            id: appSlider
            width: parent.width - appPct.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            externalValue: root.appAudio?.volume ?? 0
            stepSize: 0.05
            isMuted: root.appMuted
            handleVerticalSize: 16

            onMoved: newValue => {
                // Set the stream node directly for instant feedback, and drive
                // the app's MPRIS volume (when available) so the change survives
                // track changes. Both use the same 0-1 scale, so this does not
                // compound: the player echoes its value back onto the stream.
                if (root.appAudio)
                    root.appAudio.volume = newValue;
                if (root.mprisPlayer)
                    root.mprisPlayer.volume = newValue;
            }
        }

        Label {
            id: appPct
            text: root.appVolume + "%"
            width: 36
            horizontalAlignment: Text.AlignRight
            font.pixelSize: Typography.fontSize12
            font.weight: Font.Normal
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}

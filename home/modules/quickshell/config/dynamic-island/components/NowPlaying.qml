import QtQuick
import Quickshell.Services.Mpris
import "../"

Item {
    id: root

    readonly property var player: {
        const players = Mpris.players.values;
        let paused = null;
        for (let i = 0; i < players.length; i++) {
            const p = players[i];
            if (p.playbackState === MprisPlaybackState.Playing)
                return p;
            if (!paused && p.playbackState === MprisPlaybackState.Paused)
                paused = p;
        }
        return paused;
    }

    readonly property bool hasPlayer: player !== null
    readonly property bool isPlaying: hasPlayer && player.playbackState === MprisPlaybackState.Playing

    visible: hasPlayer
    implicitWidth: visible ? row.implicitWidth : 0
    implicitHeight: parent ? parent.height : 28
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Spacing.spacing4
        clip: true

        MusicBars {
            playing: root.isPlaying
        }

        Label {
            id: titleLabel
            text: {
                if (!root.hasPlayer) return "";
                const artist = root.player.trackArtist;
                const title = root.player.trackTitle;
                if (artist && title) return artist + " - " + title;
                if (title) return title;
                return "";
            }
            font.pixelSize: Typography.fontSize12
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            width: Math.min(implicitWidth, 180)
        }
    }

    TapHandler {
        onTapped: {
            if (root.hasPlayer) {
                if (root.isPlaying && root.player.canPause)
                    root.player.pause();
                else if (root.player.canPlay)
                    root.player.play();
            }
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}

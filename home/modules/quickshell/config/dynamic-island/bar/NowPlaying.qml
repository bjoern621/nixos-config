import QtQuick
import Quickshell.Services.Mpris
import "../"

Row {
    id: root

    property var player: null
    // Forwarded to MusicBars: Bar keeps its surface mapped while the pill is off screen.
    property bool barHidden: false
    readonly property bool hasPlayer: player !== null
    readonly property bool isPlaying: hasPlayer && player.playbackState === MprisPlaybackState.Playing

    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    spacing: Spacing.spacing4

    MusicBars {
        playing: root.isPlaying
        barHidden: root.barHidden
    }

    Label {
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

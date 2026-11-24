import QtQuick
import "../"
import "../base"

// Shown while spotify_api.py reports no valid token.
Column {
    id: root

    // False where Spotify plays no part, such as another player in the now-playing menu.
    property bool applies: true

    visible: root.applies && NowPlayingModel.spotifySignedOut
    spacing: Spacing.spacing2

    Label {
        width: root.width
        text: "Nicht bei Spotify angemeldet."
        font.pixelSize: Typography.fontSize12
        color: Colors.textColorMuted
        wrapMode: Text.Wrap
    }

    Label {
        width: root.width
        text: "Zum Anmelden im Terminal quickshell-spotify auth ausführen."
        font.pixelSize: Typography.fontSize12
        font.weight: Font.Normal
        color: Colors.textColorMuted
        wrapMode: Text.Wrap
    }
}

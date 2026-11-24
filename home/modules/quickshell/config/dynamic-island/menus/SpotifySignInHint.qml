import QtQuick
import "../"
import "../base"

// Shown while spotify_api.py reports no valid token.
// Expands in place: the first fetch to fail lands while the menu shows.
ExpandSection {
    id: root

    // False where Spotify plays no part, such as another player in the now-playing menu.
    property bool applies: true
    property int horizontalPadding: 0
    property int topPadding: 0

    expanded: root.applies && NowPlayingModel.spotifySignedOut
    // A collapsed section still takes the spacing of a parent Column.
    // Visible from the expand on, since the content inside sizes the section.
    visible: root.expanded || root.height > 0

    Column {
        x: root.horizontalPadding
        width: parent.width - 2 * root.horizontalPadding
        topPadding: root.topPadding
        spacing: Spacing.spacing2

        Label {
            width: parent.width
            text: "Nicht bei Spotify angemeldet."
            font.pixelSize: Typography.fontSize12
            color: Colors.textColorMuted
            wrapMode: Text.Wrap
        }

        Label {
            width: parent.width
            text: "Zum Anmelden im Terminal quickshell-spotify auth ausführen."
            font.pixelSize: Typography.fontSize12
            font.weight: Font.Normal
            color: Colors.textColorMuted
            wrapMode: Text.Wrap
        }
    }
}

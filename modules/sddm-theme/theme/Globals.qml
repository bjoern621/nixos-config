pragma Singleton

import QtQuick

QtObject {
    property bool volumeSliderOpen: false
    property bool launcherVisible: false
    // This is the fallback value if no wallpaper was selected ever.
    // See also WallpaperPersist.qml, WallpaperAccent.qml, WallpaperChooser.qml.
    property url wallpaperPath: "file:///home/bjoern/.local/share/wallpapers/Mist.jpg"
    readonly property color defaultAccentColor: "#ffffff"
    property color accentColor: defaultAccentColor

    // Shared SDDM auth state across all screen instances.
    property string authPassword: ""
    property bool authLoading: false
    property bool authErrorVisible: false
    property string authErrorMessage: ""
    property string authAttemptKind: ""
    property string authInputOwner: ""
    property string authQueuedAttemptKind: ""
    property string authQueuedPassword: ""
}

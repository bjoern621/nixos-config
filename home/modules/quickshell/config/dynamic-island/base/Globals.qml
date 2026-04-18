pragma Singleton

import QtQuick

QtObject {
    property bool volumeSliderOpen: false
    property bool launcherVisible: false
    property bool doNotDisturb: false
    // This is the fallback value if no wallpaper was selected ever.
    // See also WallpaperPersist.qml, WallpaperAccent.qml, WallpaperChooser.qml.
    property url wallpaperPath: "file:///home/bjoern/.local/share/wallpapers/Mist.jpg"
    readonly property color defaultAccentColor: "#ffffff"
    property color accentColor: defaultAccentColor
}

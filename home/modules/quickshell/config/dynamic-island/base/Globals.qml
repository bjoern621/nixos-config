pragma Singleton

import QtQuick
import Quickshell

QtObject {
    id: root

    // Bar is per-screen (Variants over Quickshell.screens), so a plain bool is last-writer-wins:
    // screen A's 100ms hide timer clears it while B's menu is still up.
    // Keyed by screen name, so a claim is idempotent and a screen holds at most one.
    property var _volumeSliderOwners: ({})
    readonly property bool volumeSliderOpen: Object.keys(_volumeSliderOwners).length > 0

    // Call per Bar: setVolumeSliderOpen(root.modelData.name, popupOpen).
    function setVolumeSliderOpen(screenName, open) {
        if (!screenName || (screenName in _volumeSliderOwners) === open)
            return;
        const next = Object.assign({}, _volumeSliderOwners);
        if (open)
            next[screenName] = true;
        else
            delete next[screenName];
        _volumeSliderOwners = next;
    }

    // Bar destroyed with its menu open never writes its claim back.
    // Stale claim suppresses VolumeOsd for the rest of the session.
    property Connections _volumeSliderPrune: Connections {
        target: Quickshell
        function onScreensChanged() {
            const live = Quickshell.screens.map(s => s.name);
            const kept = {};
            for (const name of Object.keys(root._volumeSliderOwners)) {
                if (live.indexOf(name) >= 0)
                    kept[name] = true;
            }
            if (Object.keys(kept).length !== Object.keys(root._volumeSliderOwners).length)
                root._volumeSliderOwners = kept;
        }
    }

    // Sole holder of launcher state.
    // AppLauncher binds to it, never mirrors it.
    // launcherScreenName is "" while the launcher is closed.
    property bool launcherVisible: false
    property string launcherScreenName: ""

    property bool doNotDisturb: false

    // Design theme: which visual language the shell renders.
    // "classic" = translucent pill UI; "neo" = neobrutalist.
    // ThemeSwitcher writes it, ThemePersist restores it, themed windows dispatch on it.
    // Only the app launcher switches on it now; other windows follow later.
    property string designTheme: "classic"
    // Fallback until a wallpaper is picked.
    // See WallpaperPersist.qml, WallpaperAccent.qml, WallpaperChooser.qml.
    property url wallpaperPath: "file:///home/bjoern/.local/share/wallpapers/Mist.jpg"
    readonly property color defaultAccentColor: "#ffffff"
    property color accentColor: defaultAccentColor
}

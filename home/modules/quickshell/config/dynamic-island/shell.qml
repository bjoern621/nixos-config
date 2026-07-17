//@ pragma UseQApplication
import Quickshell
// Explicit subdirectory imports so the QML scanner watches all files for hot reload.
import "animations"
import "bar"
import "base"
import "menus"
import "osd"
import "widgets"
import "windows"

ShellRoot {
    // Singletons construct on first use, and neither of these has a first user.
    // WallpaperPersist restores the wallpaper at startup.
    // NotificationListener owns the D-Bus server, up before the first notification.
    property var _wallpaperPersist: WallpaperPersist
    property var _notificationListener: NotificationListener

    WallpaperBackend {}
    WallpaperAccent {}
    ScreenCorners {}
    Bar {}
    PowerCorner {}
    LoadingOverlay {}
    VolumeOsd {}
    BrightnessOsd {}
    BatteryWarning {}
    ModalOverlay {}
    AppLauncher {}
    ClipboardHistory {}
    EmojiPicker {}
    WallpaperChooser {}
    NotificationToast {}
    NotificationCenter {}
}

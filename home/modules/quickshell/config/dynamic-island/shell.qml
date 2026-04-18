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
    // Force-load singletons so they're ready when needed.
    property var _loadingHost: LoadingHost
    property var _notificationListener: NotificationListener

    WallpaperPersist { id: wallpaperPersist }
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
    WallpaperChooser {}
    NotificationToast {}
    NotificationCenter {}
}

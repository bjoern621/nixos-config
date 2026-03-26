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
    // Force-load the NotificationHost singleton so the D-Bus server registers early.
    property var _notifHost: NotificationHost.server
    // Force-load LoadingHost so it's ready when needed.
    property var _loadingHost: LoadingHost

    WallpaperAccent {}
    ScreenCorners {}
    Bar {}
    PowerCorner {}
    LoadingOverlay {}
    VolumeOsd {}
    BrightnessOsd {}
    BatteryWarning {}
    PopupWindow {}
    AppLauncher {}
    ClipboardHistory {}
    NotificationToast {}
    NotificationPanel {}
}

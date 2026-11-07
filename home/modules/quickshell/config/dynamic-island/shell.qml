//@ pragma UseQApplication
import Quickshell
// Explicit subdirectory imports so the QML scanner watches all files for hot reload.
import "animations"
import "bar"
import "base"
import "logic"
import "menus"
import "osd"
import "themes"
import "widgets"
import "windows"

ShellRoot {
    // Singletons construct on first use, and none of these has a first user.
    // WallpaperPersist restores the wallpaper at startup.
    // ThemePersist restores the design theme at startup.
    // NotificationListener owns the D-Bus server, up before the first notification.
    property var _wallpaperPersist: WallpaperPersist
    property var _themePersist: ThemePersist
    property var _notificationListener: NotificationListener
    // Always-loaded launcher behavior + sole owner of the launcher GlobalShortcut.
    property var _launcherController: LauncherController

    MonitorWorkspaceSync {}
    WallpaperBackend {}
    WallpaperAccent {}
    ScreenCorners {}
    Bar {}
    PowerCorner {}
    LoadingOverlay {}
    VolumeOsd {}
    BrightnessOsd {}
    LazyLoader {
        active: HostFeatures.hasBattery
        BatteryWarning {}
    }
    ModalOverlay {}

    // Pure presentation bound to LauncherController.
    // Shortcut and all logic live in always-loaded controller.
    AppLauncherNeo {}

    ClipboardHistory {}
    EmojiPicker {}
    WindowSwitcher {}
    WallpaperChooser {}
    WallpaperPreview {}
    ThemeSwitcher {}
    NotificationToast {}
    NotificationCenter {}
}

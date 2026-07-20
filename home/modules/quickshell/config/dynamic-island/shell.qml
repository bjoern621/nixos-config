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

    // App launcher renders one design variant, chosen by Globals.designTheme.
    // Both views are pure presentation bound to LauncherController; the shortcut
    // and all logic live in the always-loaded controller, so swapping views no
    // longer double-registers the "launcher" handler.
    // FPS BISECTION: real launchers disabled, FpsTest takes the shortcut.
    LazyLoader {
        active: false
        AppLauncher {}
    }
    LazyLoader {
        active: false
        AppLauncherNeo {}
    }
    // FpsTest {} // TEMP unblock: no FpsTest.qml exists, this broke every reload. Restore once FpsTest.qml is back.

    ClipboardHistory {}
    EmojiPicker {}
    WallpaperChooser {}
    ThemeSwitcher {}
    NotificationToast {}
    NotificationCenter {}
}

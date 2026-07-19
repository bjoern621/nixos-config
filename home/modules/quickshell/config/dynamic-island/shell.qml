//@ pragma UseQApplication
import Quickshell
// Explicit subdirectory imports so the QML scanner watches all files for hot reload.
import "animations"
import "bar"
import "base"
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
    // Mutually-exclusive LazyLoaders: only the matching variant is loaded, so at
    // rest exactly one owns the "launcher" GlobalShortcut/IpcHandler.
    // At the instant of a switch both briefly coexist (Quickshell defers handler
    // unregistration), logging one benign "another handler is registered" warning;
    // once the old variant unloads the survivor's handler is the live one.
    LazyLoader {
        active: Globals.designTheme !== "neo"
        AppLauncher {}
    }
    LazyLoader {
        active: Globals.designTheme === "neo"
        AppLauncherNeo {}
    }

    ClipboardHistory {}
    EmojiPicker {}
    WallpaperChooser {}
    ThemeSwitcher {}
    NotificationToast {}
    NotificationCenter {}
}

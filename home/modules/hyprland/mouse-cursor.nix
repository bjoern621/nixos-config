{ ... }:

{
  wayland.windowManager.hyprland.settings.env = {
    # Cursor variables:
    # - XCURSOR_* is the standard Xcursor interface (used by XWayland and many toolkits).
    # - HYPRCURSOR_* is Hyprland's cursor backend (used by Hyprland-native cursor handling).
    # Setting both keeps cursor theme consistent across Wayland-native and XWayland apps.
    env = [
      "XCURSOR_THEME,Bibata-Modern-Ice" # https://www.gnome-look.org/p/1197198
      "XCURSOR_SIZE,24"
      "HYPRCURSOR_THEME,Bibata-Modern-Ice"
      "HYPRCURSOR_SIZE,24"
    ];
  };
}

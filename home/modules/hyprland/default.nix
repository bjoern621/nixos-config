{ config, pkgs, ... }:

{
  imports = [
    ./hyprpaper.nix
    ./fuzzel.nix
    ./keybinds.nix
    ./animations.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      # https://wiki.hypr.land/Configuring/Variables/#general
      general = {
        border_size = 2;
      };

      # Cursor variables:
      # - XCURSOR_* is the standard Xcursor interface (used by XWayland and many toolkits).
      # - HYPRCURSOR_* is Hyprland's cursor backend (used by Hyprland-native cursor handling).
      # Setting both keeps cursor theme consistent across Wayland-native and XWayland apps.
      env = [
        "XCURSOR_THEME,Bibata-Modern-Ice"
        "XCURSOR_SIZE,24"
        "HYPRCURSOR_THEME,Bibata-Modern-Ice"
        "HYPRCURSOR_SIZE,24"
      ];

      # https://wiki.hypr.land/Configuring/Variables/#input
      input = {
        kb_layout = "de";
        accel_profile = "flat"; # Disable mouse acceleration
          touchpad = {
            natural_scroll = true; # true: Swipe down -> content moves down
            scroll_factor = 0.5;
          };
      };

      # https://wiki.hypr.land/Configuring/Variables/#decoration
      decoration = {
        rounding = 10;

        shadow = {
          enabled = true;
        };

        blur = {
          enabled = true;
          size = 8;
          passes = 1;
        };
      };

      # Make fuzzel close instantly (disable layer animations for fuzzel)
      layerrule = [
        "noanim, ^(fuzzel)$"
      ];

      exec-once = [ "hyprpaper" ];
    };
  };
}

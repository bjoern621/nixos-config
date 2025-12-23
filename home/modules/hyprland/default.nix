{ config, pkgs, ... }:

{
  imports = [
    ./hyprpaper.nix
    ./app-launcher.nix
    ./keybinds.nix
    ./animations.nix
    ./waybar/waybar.nix
    ./clipboard-history.nix
  ];

  
  home.packages = with pkgs; [
    hyprlandPlugins.hyprbars
  ];

  wayland.windowManager.hyprland = {
    enable = true;

    plugins = [
      pkgs.hyprlandPlugins.legacyPackages.x86_64-linux.hyprlandPlugins.hyprbars
    ];

    settings = {
      # https://wiki.hypr.land/Configuring/Variables/#general
      general = {
        border_size = 0;
      };

      # plugin = [ "hyprbars" ];

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

      # https://wiki.hypr.land/Configuring/Variables/#input
      input = {
        kb_layout = "de";
        accel_profile = "flat"; # Disable mouse acceleration
        
        touchpad = {
          natural_scroll = true; # true: Swipe down -> content moves down
          scroll_factor = 0.2;
        };
      };

      # https://wiki.hypr.land/Configuring/Variables/#decoration
      decoration = {
        rounding = 10;

        shadow = {
          enabled = true;
          range = 10;
          render_power = 2;
          color = "0xee1a1a1a";
          color_inactive = "0x221a1a1a";
        };

        blur = {
          enabled = true;
          size = 8;
          passes = 1;
        };
      };
    };

  };
}

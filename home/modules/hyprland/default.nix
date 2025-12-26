{ inputs, config, pkgs, ... }:

{
  imports = [
    ./hyprpaper.nix
    ./app-launcher.nix
    ./keybinds.nix
    ./animations.nix
    ./waybar/waybar.nix
    ./clipboard-history.nix
    ./preferred-workspaces.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;

    # https://wiki.hypr.land/Useful-Utilities/Systemd-start/#uwsm
    systemd.enable = false;

    plugins = [
      inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprbars
    ];

    settings = {
      # https://wiki.hypr.land/Configuring/Variables/#general
      general = {
        border_size = 0;
      };

      # Cursor variables:
      # - XCURSOR_* is the standard Xcursor interface (used by XWayland and many toolkits).
      # - HYPRCURSOR_* is Hyprland's cursor backend (used by Hyprland-native cursor handling).
      # Setting both keeps cursor theme consistent across Wayland-native and XWayland apps.
      env = [
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

        blur.enabled = false;
      };
    };

  };
}

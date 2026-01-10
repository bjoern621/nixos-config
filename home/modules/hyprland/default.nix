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
    ./hyprpolkit.nix
    ./monitors.nix
    ./no_update_notice.nix
    ./windowrules.nix
  ];

  # Auto-start Hyprland uwsm after login
  # https://www.youtube.com/watch?v=7QLhCgDMqgw
  # https://wiki.hypr.land/Useful-Utilities/Systemd-start/#in-tty
  programs.bash = {
    enable = true;
    profileExtra = ''
      if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
        exec uwsm start hyprland-uwsm.desktop
      fi
    '';
  };

  # https://wiki.hypr.land/Nix/Hyprland-on-Home-Manager/#nixos-uwsm
  xdg.configFile."uwsm/env".source = "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";

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
        border_size = 1;
        gaps_out = "0,12,12,12";
        gaps_in = 4;
        "col.active_border" = "rgba(235,203,139,1)"; # "col.active_border" (with dot) so that Nix does not convert it to a subcategory
        "col.inactive_border" = "rgba(255,255,255,0)";
        resize_on_border = true;
      };

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

        blur.enabled = false;
      };
    };

  };
}

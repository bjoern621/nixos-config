{ config, pkgs, ... }:

{
  imports = [
    ./hyprpaper.nix
    ./fuzzel.nix
    ./keybinds.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      # https://wiki.hypr.land/Configuring/Variables/#general
      general = {
        border_size = 2;
      };

      input = {
        kb_layout = "de";
        accel_profile = "flat"; # Disable mouse acceleration

        touchpad = {
          natural_scroll = false; # false: Swipe down -> content moves down
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

      misc = {
        disable_splash_rendering = true;
      };

      # Make fuzzel close instantly (disable layer animations for fuzzel)
      layerrule = [
        "noanim, ^(fuzzel)$"
      ];

      exec-once = [ "hyprpaper" ];
    };
  };
}

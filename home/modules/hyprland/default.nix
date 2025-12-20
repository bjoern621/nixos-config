{ config, pkgs, ... }:

{
  imports = [
    ./hyprpaper.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      input = {
        kb_layout = "de";
        accel_profile = "flat"; # Disable mouse acceleration

        touchpad = {
          natural_scroll = false; # false: Swipe down -> content moves down
        };
      };

      # Pink accent color
      general = {
        "col.active_border" = "rgb(ff69b4)";
        "col.inactive_border" = "rgb(444444)";
      };

      misc = {
        disable_splash_rendering = true;
      };

      exec-once = [ "hyprpaper" ];
    };
  };
}

{ config, pkgs, ... }:

{
  wayland.windowManager.hyprland.settings = {
    input = {
      kb_layout = "de";
    };

    # Pink accent color
    general = {
      "col.active_border" = "rgb(ff69b4)";
      "col.inactive_border" = "rgb(444444)";
    };
  };
}

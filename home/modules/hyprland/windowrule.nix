{ ... }:

{
  wayland.windowManager.hyprland.settings = {
    windowrule = [
      "float,match:class mpv"
      "float,match:title Bitwarden"
    ];
  };
}
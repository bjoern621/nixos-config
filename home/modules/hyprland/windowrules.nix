{ ... }:

{
  wayland.windowManager.hyprland.settings = {
    windowrule = [
      "float on, match:class mpv"
      "float on, match:title Bitwarden"
    ];
  };
}
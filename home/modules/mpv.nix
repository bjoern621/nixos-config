{ pkgs, ... }:

{
  home.packages = with pkgs; [
    mpv
  ];

  wayland.windowManager.hyprland.settings.windowrule = [
    "float on, match:class mpv"
  ];
}

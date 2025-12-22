{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    rofi
  ];

  # SUPER key alone opens/closes fuzzel (bindr = bind on key release)
  wayland.windowManager.hyprland.settings.bindr = [
    "SUPER, Super_L, exec, pkill rofi || rofi -show drun -show-icons"
  ];
}

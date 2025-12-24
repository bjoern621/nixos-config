{ config, pkgs, ... }:

{
  # See also: https://wiki.hypr.land/Useful-Utilities/Clipboard-Managers/

  home.packages = with pkgs; [
    cliphist
    wl-clipboard
  ];

  # Watch for new clipboard content and store it in the history
  wayland.windowManager.hyprland.settings.exec-once = [
    "wl-paste -t text --watch cliphist store"
    "wl-paste -t image --watch cliphist store"
  ];

  # Bind SUPER + V to clipboard history (shown in rofi)
  wayland.windowManager.hyprland.settings.bind = [
    "SUPER, V, exec, cliphist list | rofi -dmenu -display-columns 2 | cliphist decode | wl-copy"
  ];
}

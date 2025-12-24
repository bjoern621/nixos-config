{ config, pkgs, ... }:

{
  # See also: https://wiki.hypr.land/Useful-Utilities/Clipboard-Managers/

  home.packages = with pkgs; [
    cliphist
    wl-clipboard
    wtype
  ];

  # Watch for new clipboard content and store it in the history
  wayland.windowManager.hyprland.settings.exec-once = [
    "wl-paste -t text --watch cliphist store"
    "wl-paste -t image --watch cliphist store"
  ];

  # Bind SUPER + V to clipboard history (shown in rofi)
  # Selecting an entry copies it again to the clipboard and pastes it at the cursor using Ctrl+Shift+V (works in most applications and terminals)
  # wtype: -M key holds the modifier, -m key releases it. So -M ctrl -M shift v -m shift -m ctrl simulates Ctrl+Shift+V.
  wayland.windowManager.hyprland.settings.bind = [
    "SUPER, V, exec, cliphist list | rofi -dmenu -display-columns 2 | cliphist decode | wl-copy && wtype -M ctrl -M shift v -m shift -m ctrl"
  ];
}

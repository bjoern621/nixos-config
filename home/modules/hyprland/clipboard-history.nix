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

  # Bind SUPER + V to clipboard history (shown in quickshell)
  # The clipboard menu uses IPC to toggle visibility within the already-running quickshell process.
  # Selecting an entry copies it again to the clipboard and pastes it at the cursor using Ctrl+Shift+V.
  wayland.windowManager.hyprland.settings.bind = [
    "SUPER, V, exec, qs ipc call clipboard toggle"
  ];
}

{ pkgs, ... }:

{
  wayland.windowManager.hyprland.settings.exec-once = [
    "[workspace 1 silent] uwsm app -- google-chrome.desktop"
    "[workspace 2 silent] uwsm app -- code.desktop"
  ];
}

{ config, pkgs, ... }:

{
  wayland.windowManager.hyprland.settings = {
    exec = [
      "nm-applet --indicator" # NetworkManager tray applet
    ];
  };
}

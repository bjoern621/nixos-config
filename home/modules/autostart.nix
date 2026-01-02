{ config, pkgs, ... }:

{
  wayland.windowManager.hyprland.settings = {
    exec = [
      "discord"
    ];
  };
}

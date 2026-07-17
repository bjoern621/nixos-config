{ pkgs, ... }:

{
  home.packages = [
    pkgs.playerctl
  ];

  wayland.windowManager.hyprland.extraLuaFiles."media-keys".content = ./media-keys.lua;
}

{ pkgs, ... }:

{
  wayland.windowManager.hyprland.extraLuaFiles."hyprpolkit".content = ./hyprpolkit.lua;

  home.packages = [
    pkgs.hyprpolkitagent
  ];
}

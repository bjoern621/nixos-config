{ pkgs, ... }:

{
  home.packages = with pkgs; [
    mpv
  ];

  wayland.windowManager.hyprland.extraLuaFiles."rules.31-mpv".content = ./mpv.lua;
}

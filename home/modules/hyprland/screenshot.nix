{ pkgs, ... }:

{
  home.packages = with pkgs; [
    swappy # Screenshot editing
    grim # Capture image from screen
    slurp # Area selection tool, outputting coordinates to grim
    wayfreeze # Freeze screen for screenshot selection
  ];

  wayland.windowManager.hyprland.extraLuaFiles."screenshot".content = ./screenshot.lua;
}

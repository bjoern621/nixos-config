{ pkgs, ... }:

{
  home.packages = with pkgs; [
    swappy # Screenshot editing
    grim # Capture image from screen
    slurp # Area selection tool, outputting coordinates to grim
    wayfreeze # Freeze screen for screenshot selection
  ];

  xdg.configFile."swappy/config".text = ''
    [Default]
    save_dir=$HOME/Downloads
    save_filename_format=swappy-%Y%m%d-%H%M%S.png
  '';

  wayland.windowManager.hyprland.extraLuaFiles."screenshot".content = ./screenshot.lua;
}

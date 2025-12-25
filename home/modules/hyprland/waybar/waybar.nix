{ pkgs, lib, ... }:

let
  powerMenu = pkgs.writeShellScriptBin "power-menu" (builtins.readFile ./power-menu.sh);
in
{
  programs.waybar = {
    enable = true;
    style = builtins.readFile ./waybar.css;
    settings = lib.importJSON ./waybar.json;
  };

  wayland.windowManager.hyprland.settings.exec-once = [ "waybar" ];

  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    font-awesome // Icons
  ];
}

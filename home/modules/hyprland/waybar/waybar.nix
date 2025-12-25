{ pkgs, ... }:

let
  powerMenu = pkgs.writeShellScriptBin "power-menu" (builtins.readFile ./power-menu.sh);
in
{
  programs.waybar = {
    enable = true;
    style = builtins.readFile ./waybar.css;
    programs.waybar.settings = lib.importJSON ./waybar.json;
  };

  wayland.windowManager.hyprland.settings.exec-once = [ "waybar" ];
}

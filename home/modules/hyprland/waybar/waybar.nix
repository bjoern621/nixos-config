{ pkgs, ... }:

let
  powerMenu = pkgs.writeShellScriptBin "power-menu" (builtins.readFile ./power-menu.sh);
in
{
  programs.waybar = {
    enable = true;
    style = builtins.readFile ./waybar.css;
    settings = builtins.fromJSON (builtins.readFile ./waybar.jsonc);
  };

  wayland.windowManager.hyprland.settings.exec-once = [ "waybar" ];
}

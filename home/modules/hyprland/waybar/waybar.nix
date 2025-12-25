{ pkgs, ... }:

let
  powerMenu = pkgs.writeShellScriptBin "power-menu" (builtins.readFile ./power-menu.sh);
in
{
  programs.waybar = {
    enable = true;
    style = builtins.readFile ./waybar.css;
    settings = (pkgs.formats.json {}).fromFile ./waybar.jsonc // {
      mainBar."custom/powermenu"."on-click" = "${powerMenu}/bin/power-menu";
    };
  };

  wayland.windowManager.hyprland.settings.exec-once = [ "waybar" ];
}

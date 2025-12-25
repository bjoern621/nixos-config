{ pkgs, ... }:

let
  powerMenu = pkgs.writeShellScriptBin "power-menu" (builtins.readFile ./power-menu.sh);

  # Read the user's JSON config
  waybarConfig = (pkgs.formats.jsonc {}).fromFile ./waybar.json;
in
{
  # Just enable the waybar program and service
  programs.waybar.enable = true;

  # Use home.xdg.configFile to place the generated config and the stylesheet
  home.xdg.configFile."waybar/config".text = builtins.toJSON waybarConfig;
  home.xdg.configFile."waybar/style.css".source = ./waybar.css;

  # Ensure waybar starts with Hyprland
  wayland.windowManager.hyprland.settings.exec-once = [ "waybar" ];
}

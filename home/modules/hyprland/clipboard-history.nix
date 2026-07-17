{ pkgs, ... }:

{
  # See also: https://wiki.hypr.land/Useful-Utilities/Clipboard-Managers/

  home.packages = with pkgs; [
    cliphist
    wl-clipboard
    wtype
  ];

  wayland.windowManager.hyprland.extraLuaFiles."clipboard-history".content = ./clipboard-history.lua;
}

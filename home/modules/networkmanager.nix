{ config, pkgs, ... }:

/*
  NetworkManager tray applet for managing network connections (including VPN).
  WireGuard VPN setup is documented in modules/wireguard.nix.
*/

{
  wayland.windowManager.hyprland.extraLuaFiles."networkmanager".content = ./networkmanager.lua;
}

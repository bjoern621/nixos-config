{ config, pkgs, ... }:

/*
  NetworkManager tray applet for managing network connections (including VPN).
  WireGuard VPN setup is documented in modules/wireguard.nix.
*/

{
  wayland.windowManager.hyprland.extraLuaFiles."networkmanager".content = ./networkmanager.lua;

  # Override icon: upstream uses "preferences-system-network" which is missing in Adwaita
  xdg.desktopEntries."nm-connection-editor" = {
    name = "Erweiterte Netzwerkkonfiguration";
    genericName = "Advanced Network Configuration";
    comment = "Verwaltung von Einstellungen für Netzwerkverbindungen";
    exec = "nm-connection-editor";
    icon = "preferences-system-network-symbolic";
    terminal = false;
    startupNotify = true;
    type = "Application";
    categories = [
      "GNOME"
      "GTK"
      "Settings"
    ];
  };
}

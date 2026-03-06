{ config, pkgs, ... }:

{
  wayland.windowManager.hyprland.settings = {
    exec = [
      # Add autostart entries in their respective feature modules
      # (e.g., nm-applet is in networkmanager.nix)
    ];
  };
}

{ config, pkgs, ... }:

{
  # Enable Hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Hint Electron apps to use Wayland
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
  };

  # XDG Portal for Hyprland
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
  };

  # System packages required for Hyprland
  environment.systemPackages = with pkgs; [
    kitty
    waybar
    wofi
    dunst
    swww
    grim
    slurp
    wl-clipboard
    brightnessctl
    networkmanagerapplet
  ];

  # Enable polkit for authentication dialogs
  security.polkit.enable = true;
}

{ config, pkgs, ... }:

{
  imports = [
    ./modules/hyprland.nix
    ./modules/spotify.nix
    ./modules/discord.nix
  ];

  home.username = "bjoern";
  home.homeDirectory = "/home/bjoern";

  # User packages
  home.packages = with pkgs; [
    google-chrome
    firefox
  ];

  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}

{ config, pkgs, ... }:

{
  imports = [
    ./modules/spotify.nix
    ./modules/discord.nix
    ./modules/hyprland
  ];

  home.username = "bjoern";
  home.homeDirectory = "/home/bjoern";

  # User packages
  home.packages = with pkgs; [
    google-chrome
    firefox
    git
  ];

  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}

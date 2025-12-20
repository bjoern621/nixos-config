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
    unzip
    htop
    neofetch
  ];

  # Git configuration
  programs.git = {
    enable = true;
    userName = "Björn";
    userEmail = ""; # Set email address
  };

  # Terminal
  programs.kitty = {
    enable = true;
    settings = {
      font_size = 12;
      background_opacity = "0.9";
      confirm_os_window_close = 0;
    };
  };

  # Shell
  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -la";
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#nixos";
      update = "nix flake update /etc/nixos";
    };
  };

  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}

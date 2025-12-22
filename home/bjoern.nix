{ config, pkgs, ... }:

{
  imports = [
    ./modules/spotify.nix
    ./modules/discord.nix
    ./modules/hyprland
    ./modules/terminals.nix
    ./modules/vscode.nix
  ];

  home.username = "bjoern";
  home.homeDirectory = "/home/bjoern";

  home.pointerCursor = {
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 24;

    # Applies the cursor theme through GTK settings (GTK apps, portals, and many desktop components).
    gtk.enable = true;

    # Exports Xcursor settings for X11/XWayland clients (some Electron/legacy apps still read Xcursor).
    x11.enable = true;
  };

  # User packages
    home.packages = with pkgs; [
      firefox
      git
      kdePackages.kate
      vlc
    ];

  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  programs.npm.enable = true;
}

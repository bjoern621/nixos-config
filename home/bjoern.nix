{ inputs, config, pkgs, ... }:

{
  imports = [
    ./modules/spotify.nix
    ./modules/discord.nix
    ./modules/hyprland/default.nix
    ./modules/terminal.nix
    ./modules/vscode.nix
    ./modules/bitwarden.nix
    ./modules/task-manager.nix
    ./modules/git.nix
  ];

  home.username = "bjoern";
  home.homeDirectory = "/home/bjoern";

  # https://wiki.hypr.land/Nix/Hyprland-on-Home-Manager/#fixing-problems-with-themes

  home.pointerCursor = {
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 24;

    # Applies the cursor theme through GTK settings (GTK apps, portals, and many desktop components).
    gtk.enable = true;

    # Exports Xcursor settings for X11/XWayland clients (some Electron/legacy apps still read Xcursor).
    x11.enable = true;
  };

  gtk = {
    enable = true;

    theme = {
      package = pkgs.flat-remix-gtk;
      name = "Flat-Remix-GTK-Grey-Darkest";
    };

    iconTheme = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
    };

    font = {
      name = "Inter Bold";
      size = 11;
    };
  };

  # User packages
  home.packages = with pkgs; [
    firefox
    git
    kdePackages.kate
    mpv
  ];

  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  programs.npm.enable = true;
}

{
  inputs,
  config,
  pkgs,
  ...
}:

{
  imports = [
    ./modules/spotify.nix
    ./modules/discord.nix
    ./modules/autostart.nix
    ./modules/networkmanager.nix
    ./modules/hyprland/default.nix
    ./modules/terminal.nix
    ./modules/vscode.nix
    ./modules/bitwarden.nix
    ./modules/git.nix
    ./modules/mission-center.nix
    ./modules/google-chrome.nix
    ./modules/desktop-theme.nix
    ./modules/desktop-portals.nix
    ./user-packages.nix
    ./modules/quickshell/quickshell.nix
    ./modules/paintdotnet.nix
    ./modules/shell.nix
    ./modules/ssh-connect-homelab.nix
    ./modules/file-manager.nix
    ./modules/keyring.nix
    ./modules/image-viewer.nix
    ./modules/mpv.nix
  ];

  home.username = "bjoern";
  home.homeDirectory = "/home/bjoern";

  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}

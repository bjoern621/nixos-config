{
  inputs,
  config,
  pkgs,
  ...
}:

{
  imports = [
    ./host.nix
    ./modules/spotify.nix
    ./modules/discord.nix
    ./modules/networkmanager.nix
    ./modules/hyprland/default.nix
    ./modules/terminal.nix
    ./modules/terminal-drop.nix
    ./modules/vscode.nix
    ./modules/claude-code.nix
    ./modules/bitwarden.nix
    ./modules/calendar.nix
    ./modules/git.nix
    ./modules/mission-center.nix
    ./modules/google-chrome.nix
    ./modules/desktop-theme.nix
    ./modules/desktop-portals.nix
    ./modules/xdg-user-dirs.nix
    ./user-packages.nix
    ./modules/kubernetes.nix
    ./modules/ksystemlog.nix
    ./modules/wdisplays.nix
    ./modules/quickshell/quickshell.nix
    ./modules/paintdotnet.nix
    ./modules/shell.nix
    ./modules/yazi/yazi.nix
    ./modules/nix-index.nix
    ./modules/ssh-connect-homelab.nix
    ./modules/file-manager.nix
    ./modules/keyring.nix
    ./modules/image-viewer.nix
    ./modules/mpv.nix
    ./modules/tailscale-client.nix
    ./modules/direnv.nix
    ./modules/scanning.nix
    ./modules/firewall-viewer.nix
    ./modules/screen-sharing.nix
    ./modules/usbguard.nix
    ./modules/handy.nix
    ./modules/gnome-text-editor/gnome-text-editor.nix
  ];

  home.username = "bjoern";
  home.homeDirectory = "/home/bjoern";

  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}

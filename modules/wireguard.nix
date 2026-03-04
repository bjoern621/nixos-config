{ pkgs, ... }:

/*
  NetworkManager manages all network connections in one place — wifi, ethernet,
  and VPN (including WireGuard). Benefits over wg-quick on a desktop:
    - Single tray applet (nm-applet) to toggle any connection
    - Integrates with the system keyring for credential storage
    - Handles DNS, routing, and interface lifecycle centrally
    - Per-connection profiles survive reboots without manual systemctl

  WireGuard setup (one-time, after first rebuild):
    sudo nmcli connection import type wireguard file /etc/wireguard/xyz.conf

  The conf file lives at /etc/wireguard/xyz.conf (outside the git repo).
  See modules/wireguard.conf.example for the template.

  Manage via tray:
    nm-applet runs on login (see home/modules/autostart.nix)
    Right-click tray icon -> VPN connections -> xyz

  Manage via CLI:
    nmcli connection up   xyz
    nmcli connection down xyz
    nmcli connection show xyz
    wg show
*/

{
  # networkmanager is enabled in hosts/default/configuration.nix
  environment.systemPackages = with pkgs; [
    wireguard-tools # wg, wg-quick
    networkmanagerapplet # nm-applet (tray) + nm-connection-editor (GUI)
  ];
}

{ pkgs, ... }:

/*
  NetworkManager manages all network connections in one place — wifi, ethernet,
  and VPN (including WireGuard). Benefits over wg-quick on a desktop:
    - Single tray applet (nm-applet) to toggle any connection
    - Integrates with the system keyring for credential storage
    - Handles DNS, routing, and interface lifecycle centrally
    - Per-connection profiles survive reboots without manual systemctl

  WireGuard setup (one-time, after first rebuild):
    sudo nmcli connection import type wireguard file /etc/wireguard/wg-hamburg.conf

  The conf file lives at /etc/wireguard/wg-hamburg.conf (outside the git repo).
  See modules/wireguard.conf.example for the template.

  Manage via tray:
    nm-applet runs on login (see home/modules/autostart.nix)
    Right-click tray icon -> VPN connections -> wg-hamburg

  Manage via CLI:
    nmcli connection up   wg-hamburg
    nmcli connection down wg-hamburg
    nmcli connection show wg-hamburg
    wg show
*/

{
  # networkmanager is enabled in hosts/default/configuration.nix
  environment.systemPackages = with pkgs; [
    wireguard-tools # wg, wg-quick
    networkmanagerapplet # nm-applet (tray) + nm-connection-editor (GUI)
  ];
}

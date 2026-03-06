{ pkgs, ... }:

/*
  NetworkManager manages all network connections in one place — wifi, ethernet,
  and VPN (including WireGuard). Benefits over wg-quick on a desktop:
    - Single tray applet (nm-applet) to toggle any connection
    - Integrates with the system keyring for credential storage
    - Handles DNS, routing, and interface lifecycle centrally
    - Per-connection profiles survive reboots without manual systemctl

  Adding a new WireGuard connection:
    1. Place the conf file at /etc/wireguard/<name>.conf (outside the git repo)
    2. Import into NetworkManager:
         sudo nmcli connection import type wireguard file /etc/wireguard/<name>.conf
    3. Disable autoconnect (VPN should not start on boot):
         sudo nmcli connection modify <name> connection.autoconnect no

  Multiple conf files can coexist in /etc/wireguard/, one per VPN endpoint.
  Repeat the import steps for each new connection.

  Manage via tray:
    nm-applet runs on login (see home/modules/networkmanager.nix)
    Right-click tray icon -> VPN connections -> <name>

  Manage via CLI:
    nmcli connection up   <name>
    nmcli connection down <name>
    nmcli connection show <name>
    wg show
*/

{
  # networkmanager is enabled in hosts/default/configuration.nix
  environment.systemPackages = with pkgs; [
    wireguard-tools # wg, wg-quick
    networkmanagerapplet # nm-applet (tray) + nm-connection-editor (GUI)
  ];
}

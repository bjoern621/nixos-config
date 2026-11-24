{ ... }:

/*
  Keeps nm-applet out of tray.
  Quickshell bar network menu covers WLAN + VPN.
  WireGuard VPN setup is documented in modules/wireguard.nix.
*/

{
  # networkmanagerapplet ships nm-applet.desktop into /etc/xdg/autostart.
  # Hidden=true makes systemd-xdg-autostart-generator skip it.
  xdg.configFile."autostart/nm-applet.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=NetworkManager Applet
    Exec=nm-applet
    Hidden=true
  '';
}

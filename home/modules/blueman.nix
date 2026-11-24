{ ... }:

/*
  Keeps blueman-applet out of tray.
  Quickshell bar Bluetooth menu covers device list + pairing.
  services.blueman stays on in host configs: bar opens blueman-manager.
  Without applet, no BlueZ agent answers PIN or passkey prompts.
*/

{
  # services.blueman ships blueman.desktop into /etc/xdg/autostart.
  # Hidden=true makes systemd-xdg-autostart-generator skip it.
  xdg.configFile."autostart/blueman.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Blueman Applet
    Exec=blueman-applet
    Hidden=true
  '';
}

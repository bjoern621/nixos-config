{ pkgs, ... }:

{
  # Chromecast needs LAN only; Miracast needs Wi-Fi P2P in wpa_supplicant.
  environment.systemPackages = [
    pkgs.gnome-network-displays
  ];

  # Chromecast discovery (mDNS).
  services.avahi = {
    enable = true;
    openFirewall = true;
  };

  # WiFi Display (Miracast/WFD) ports
  networking.firewall = {
    allowedTCPPorts = [
      7236
      7250
    ];
    allowedUDPPorts = [
      7236
      5004
    ];
  };
}

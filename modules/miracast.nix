{ pkgs, ... }:

{
  # Neither does work currently
  environment.systemPackages = [
    pkgs.gnome-network-displays
    pkgs.miraclecast
  ];

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

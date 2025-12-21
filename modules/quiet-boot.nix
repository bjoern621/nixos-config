{ config, pkgs, ... }:

{
  boot.kernelParams = [
    "quiet"
    "loglevel=3"
    "udev.log_level=3"
    "rd.udev.log_level=3"
    "systemd.show_status=false"
    "rd.systemd.show_status=false"
  ];

  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;

  # Instantly select latest NixOS profile
  boot.loader.timeout = 0;
}

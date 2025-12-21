{ config, pkgs, ... }:

{
  boot.kernelParams = [
    "quiet"
  ];

  # Instantly select latest NixOS profile
  boot.loader.timeout = 0;
  boot.loader.systemd-boot.default = "auto";
}

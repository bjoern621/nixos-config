{ config, pkgs, ... }:

{
  boot.kernelParams = [
    "quiet"
  ];

  # Instantly select latest NixOS profile
  boot.loader.timeout = 0;
}

{ config, pkgs, ... }:

{
  boot.kernelParams {
    "quiet"
  };
}

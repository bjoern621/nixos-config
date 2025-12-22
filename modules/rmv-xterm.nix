{ config, pkgs, ... }:

{
  services.xserver.excludePackages = [ pkgs.xterm ];
}

{ config, pkgs, ... }:

{
  imports = [
    ./sysconf-pull.nix
    ./sysconf-update.nix
    ./sysconf-reload.nix
  ];
}

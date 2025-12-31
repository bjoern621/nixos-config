{ config, pkgs, ... }:

{
  imports = [
    ./scripts/sysconf-pull.nix
    ./scripts/sysconf-update.nix
    ./scripts/sysconf-reload.nix
  ];
}

{ config, pkgs, ... }:

{
  imports = [
    ./sysconf-pull.nix
    ./sysconf-update.nix
    ./sysconf-stable-update.nix
    ./sysconf-reload.nix
    ./sysconf-help.nix
    ./sysconf-audio-fix.nix
    ./sysconf-fix-monitors.nix
  ];
}

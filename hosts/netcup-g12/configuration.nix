{ ... }:

{
  imports = [
    ./machine.nix
    ./hardware-configuration.nix
    ../../modules/server-base.nix
    ../../modules/mediamtx-relay.nix
  ];

  time.timeZone = "Europe/Berlin";
}

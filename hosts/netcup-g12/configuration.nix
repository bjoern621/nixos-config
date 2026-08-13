{ ... }:

{
  imports = [
    ./machine.nix
    ./hardware-configuration.nix
    ../../modules/server-base.nix
    ../../modules/sops.nix
    ../../modules/scripts
    ../../modules/sysconf-checkout.nix
    ../../modules/sysconf-auto-pull.nix
    ../../modules/mediamtx-relay.nix
    ../../modules/screenshare-groupd.nix
    ../../modules/screenshare-proxy.nix
  ];

  sysconf.checkout.enable = true;

  services.sysconf-auto-pull = {
    enable = true;
    user = "root";
    schedule = "daily";
  };

  time.timeZone = "Europe/Berlin";

  # A CNAME onto this machine's own name, so one certificate covers the relay and the group
  # service.
  screenshare.domain = "streamrelay.bjoernblessin.de";
}

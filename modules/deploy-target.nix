# Where `sysconf-reload --remote` sends this host.
#
# The address belongs to the machine, so it is declared with the machine rather than
# retyped on every deploy.
# Read by the script through `nix eval`, and by nothing in the built system.

{ lib, ... }:

{
  options.deploy.targetHost = lib.mkOption {
    type = lib.types.str;
    example = "root@server.example";
    description = ''
      ssh destination `nixos-rebuild --target-host` activates this host through.
      Carries the user, because the closure is copied and activated as root.
    '';
  };
}

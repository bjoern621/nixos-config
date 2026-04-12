{ ... }:
{
  # Placeholder hardware configuration.
  #
  # This file exists so the flake can be evaluated from the repository without
  # importing an absolute path like /etc/nixos/hardware-configuration.nix.
  #
  # On the NixOS host, the sysconf-update script overwrites this file by copying
  # /etc/nixos/haconf.nix to hosts/default/hardware-configuration.nix in the
  # synced config directory.
}

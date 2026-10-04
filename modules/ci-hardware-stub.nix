# Stands in for the machine's own hardware-configuration.nix on hosts that keep a placeholder
# in git and take the real file from /etc/nixos at sysconf-reload time.
# Supplies the values a NixOS eval refuses to proceed without,
# so the host's package set builds on a runner with no machine present.
#
# Layered onto a separate nixosConfigurations attribute, never onto the one a host deploys.
# mkDefault throughout, so the machine's own values win if the two ever meet.

{ lib, ... }:

{
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # systemd-boot asserts its ESP is a mount point.
  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
  };
}

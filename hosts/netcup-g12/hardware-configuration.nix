# Written by hand rather than by nixos-generate-config: the layout is the image
# builder's, not the installer's.
#
# nixpkgs' disk-image module lays down an ext4 root labelled nixos and, for the EFI
# variant, a vfat ESP labelled ESP, and it grows the root partition to the disk on
# first boot.
# The virtio modules the initrd needs come from the qemu-guest profile in machine.nix.
#
# Refresh it from the machine with:
#   ssh netcup-g12 nixos-generate-config --dir /tmp/hw

{ ... }:

{
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    autoResize = true;
  };

  # Where systemd-boot installs, so a generation added by a remote rebuild reaches the
  # firmware.
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
  };

  swapDevices = [ ];
}

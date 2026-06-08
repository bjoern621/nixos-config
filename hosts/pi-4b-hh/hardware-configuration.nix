{ ... }:
{
  # Hardware configuration for Raspberry Pi 4B SD card images.
  #
  # The firmware partition (mmcblk0p1, vfat, label FIRMWARE) is not mounted
  # at runtime; only the root is needed here. The sd-image-aarch64 module
  # handles partition layout at image build time.
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };
}

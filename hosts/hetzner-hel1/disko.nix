# Disk layout nixos-anywhere formats and the running system mounts.
#
# Hetzner Cloud boots this line in BIOS mode, so GRUB lands in the 1M partition and no
# ESP exists. disko reads the EF02 type and names the disk to GRUB itself.

{ ... }:

{
  disko.devices.disk.main = {
    device = "/dev/sda";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "1M";
          type = "EF02";
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
            extraArgs = [
              "-L"
              "nixos"
            ];
          };
        };
      };
    };
  };
}

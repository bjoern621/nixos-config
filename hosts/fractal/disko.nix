# Disk layout nixos-anywhere formats and the running system mounts.
#
# One disk, the Crucial T700. Mounts go by partlabel, so `device` matters at format time alone.
# nixos-anywhere names the real device with `--disk main /dev/disk/by-id/nvme-CT2000T700SSD3_<serial>`
# (docs/fractal.md); the value here opens nothing, so a run without that flag stops instead of
# formatting whichever disk enumerated first.

{ ... }:

{
  disko.devices.disk.main = {
    device = "/dev/null";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            # The passphrase file nixos-anywhere carries over with --disk-encryption-keys.
            passwordFile = "/tmp/cryptroot.key";
            settings.allowDiscards = true;
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}

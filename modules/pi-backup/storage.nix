{
  config,
  lib,
  ...
}:

# LUKS-encrypted backup volume on the Pi. Mounted nofail so a missing
# drive does not block boot. Snapshots live at `mountPoint/snapshots/<job>/`.

let
  cfg = config.services.pi-backup.storage;
in
{
  options.services.pi-backup.storage = {
    enable = lib.mkEnableOption "LUKS-encrypted backup volume";

    deviceUuid = lib.mkOption {
      type = lib.types.str;
      example = "00000000-0000-0000-0000-000000000000";
      description = "UUID of the LUKS partition. From `blkid` after `cryptsetup luksFormat`.";
    };

    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/srv/backups";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.initrd.luks.devices."backup" = {
      device = "/dev/disk/by-uuid/${cfg.deviceUuid}";
      allowDiscards = true;
    };

    fileSystems."${cfg.mountPoint}" = {
      device = "/dev/mapper/backup";
      fsType = "ext4";
      options = [
        "noatime"
        "nofail"
      ];
    };

    # 0700: contents are unencrypted once LUKS is open.
    systemd.tmpfiles.rules = [
      "d ${cfg.mountPoint} 0700 root root - -"
      "d ${cfg.mountPoint}/snapshots 0700 root root - -"
    ];
  };
}

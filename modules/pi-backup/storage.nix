{
  config,
  lib,
  ...
}:

let
  cfg = config.services.pi-backup.storage;
in
{
  options.services.pi-backup.storage = {
    enable = lib.mkEnableOption "LUKS-encrypted backup volume mounted at /srv/backups";

    deviceUuid = lib.mkOption {
      type = lib.types.str;
      example = "00000000-0000-0000-0000-000000000000";
      description = ''
        UUID of the LUKS-encrypted partition on the external drive.
        Find it with `lsblk -o NAME,UUID` after running `cryptsetup luksFormat`.
      '';
    };

    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/srv/backups";
      description = "Where the unlocked backup volume is mounted.";
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
      # nofail: a disconnected/dead backup drive must not prevent the Pi from booting.
      options = [
        "noatime"
        "nofail"
      ];
    };

    # 0700 root-only: snapshots contain unencrypted Bitwarden vault data once LUKS is open.
    systemd.tmpfiles.rules = [
      "d ${cfg.mountPoint} 0700 root root - -"
      "d ${cfg.mountPoint}/snapshots 0700 root root - -"
    ];
  };
}

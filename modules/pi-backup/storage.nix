{
  config,
  lib,
  ...
}:

# LUKS-encrypted backup volume on the Pi. Snapshots live at `mountPoint/snapshots/<job>/`.
# A key file on the SD card unlocks it after boot, so the headless Pi boots without a prompt.
# The key protects a stolen disk, not a stolen Pi. The passphrase in the other key slot stays offline.
# Unlock and mount are nofail: a missing drive does not block boot.

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

    keyFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/pi-backup/luks.key";
      description = "Key file in a LUKS key slot, root-only on the SD card. Created out-of-band, never in the Nix store.";
    };

    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/srv/backups";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc.crypttab.text = ''
      backup UUID=${cfg.deviceUuid} ${cfg.keyFile} luks,discard,nofail
    '';

    fileSystems."${cfg.mountPoint}" = {
      device = "/dev/mapper/backup";
      fsType = "ext4";
      options = [
        "noatime"
        "nofail"
      ];
    };

    # Contents are unencrypted once LUKS is open, so each tenant keeps its own directory closed.
    # 0711 lets the Garage service user through to its directory.
    systemd.tmpfiles.rules = [
      "d ${cfg.mountPoint} 0711 root root - -"
      "d ${cfg.mountPoint}/snapshots 0700 root root - -"
    ];
  };
}

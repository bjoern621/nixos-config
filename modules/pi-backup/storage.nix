{
  config,
  lib,
  pkgs,
  ...
}:

# LUKS-encrypted backup volume on the Pi. Snapshots live at `mountPoint/snapshots/<job>/`.
# A key file on the SD card unlocks it after boot, so the headless Pi boots without a prompt.
# The key protects a stolen disk, not a stolen Pi. The passphrase in the other key slot stays offline.
# Unlock and mount are nofail: a missing drive does not block boot.

let
  cfg = config.services.pi-backup.storage;

  # Root 0711: contents are unencrypted once LUKS is open, so each tenant keeps its own directory closed.
  rules = pkgs.writeText "pi-backup-volume.conf" (
    lib.concatStrings (
      [ "d ${cfg.mountPoint} 0711 root root - -\n" ]
      ++ lib.mapAttrsToList (
        path: d: "d ${cfg.mountPoint}/${path} ${d.mode} ${d.user} ${d.group} - -\n"
      ) cfg.directories
    )
  );

  directoryModule = lib.types.submodule {
    options = {
      mode = lib.mkOption {
        type = lib.types.str;
        default = "0700";
      };
      user = lib.mkOption {
        type = lib.types.str;
        default = "root";
      };
      group = lib.mkOption {
        type = lib.types.str;
        default = "root";
      };
    };
  };
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

    directories = lib.mkOption {
      type = lib.types.attrsOf directoryModule;
      default = { };
      example = {
        garage = {
          user = "garage";
          group = "garage";
        };
      };
      description = ''
        Directories on the volume, by path under `mountPoint`.
        pi-backup-volume.service creates them once the volume is mounted.
        A service writing there requires that unit: systemd sets up `ReadWritePaths` before any `ExecStartPre`, and fails on a path that does not exist yet.
      '';
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

    services.pi-backup.storage.directories.snapshots = { };

    # Not systemd-tmpfiles-setup: that runs before the nofail mount and would create the paths on the SD card.
    systemd.services.pi-backup-volume = {
      description = "Create the tenant directories on the backup volume";
      wantedBy = [ "multi-user.target" ];
      unitConfig = {
        RequiresMountsFor = [ cfg.mountPoint ];
        ConditionPathIsMountPoint = cfg.mountPoint;
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.systemd}/bin/systemd-tmpfiles --create ${rules}";
      };
    };
  };
}

{
  config,
  lib,
  pkgs,
  ...
}:

# Exposes named source trees as a read-only rrsync chroot for off-host
# pull backups. Each `sources.<name>` is bind-mounted under
# `chrootRoot/<name>` and reachable as `<name>/...` from the pull host.
# Authorized keys are installed on root because some source trees contain
# files owned by container runtime UIDs that an unprivileged user cannot
# read; the forced-command + `restrict` keyword still constrains each key
# to one read-only rsync rooted at `chrootRoot`.

let
  cfg = config.services.backup-source;

  authorizedKeyType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        example = "pi-backup-01";
        description = "Comment appended to the key entry, used to revoke individual hosts.";
      };
      key = lib.mkOption {
        type = lib.types.str;
        description = "Public key string (`ssh-<algo> AAAA...`), no command prefix.";
      };
    };
  };

  mountUnits = lib.mapAttrs' (
    name: src:
    lib.nameValuePair "${cfg.chrootRoot}/${name}" {
      device = src;
      fsType = "none";
      options = [
        "bind"
        "ro"
        "nofail"
        "x-systemd.requires-mounts-for=${src}"
      ];
    }
  ) cfg.sources;
in
{
  options.services.backup-source = {
    enable = lib.mkEnableOption "read-only rrsync chroot for off-host pull backups";

    chrootRoot = lib.mkOption {
      type = lib.types.path;
      default = "/srv/backup-source";
      description = "rrsync chroot root. Each source is bind-mounted under here.";
    };

    sources = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      example = lib.literalExpression ''
        {
          bitwarden = "/var/backups/bitwarden";
          k3s-pvcs  = "/var/lib/rancher/k3s/storage";
        }
      '';
      description = "Source trees to expose under `chrootRoot/<name>` as read-only bind mounts.";
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf authorizedKeyType;
      default = [ ];
      description = "Pubkeys authorized to pull. Each becomes a forced-command entry on root pinned to `rrsync -ro <chrootRoot>`.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.chrootRoot} 0755 root root - -"
    ]
    ++ lib.mapAttrsToList (name: _src: "d ${cfg.chrootRoot}/${name} 0755 root root - -") cfg.sources;

    fileSystems = mountUnits;

    users.users.root.openssh.authorizedKeys.keys = map (
      k: ''command="${pkgs.rsync}/bin/rrsync -ro ${cfg.chrootRoot}",restrict ${k.key} ${k.name}''
    ) cfg.authorizedKeys;
  };
}

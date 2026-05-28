{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.backup-source;

  authorizedKeyType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        example = "pi-backup-01";
        description = "Comment appended to the key entry; used by humans to identify the Pi.";
      };
      key = lib.mkOption {
        type = lib.types.str;
        description = "The full `ssh-<algo> AAAA...` public key string (no command prefix).";
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
    enable = lib.mkEnableOption "expose a read-only rsync chroot consolidating one or more source trees";

    chrootRoot = lib.mkOption {
      type = lib.types.path;
      default = "/srv/backup-source";
      description = ''
        Path under which each entry in `sources` is exposed via a
        read-only bind mount. This is also the rrsync chroot root, so
        a compromised key can read nothing outside this tree.
      '';
    };

    sources = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      example = lib.literalExpression ''
        {
          bitwarden  = "/var/backups/bitwarden";
          webdav-pvc = "/var/lib/rancher/k3s/storage";
        }
      '';
      description = ''
        Source trees to expose under `chrootRoot/<name>` as read-only
        bind mounts. The pi-side rsync requests `<name>/...` and rrsync
        resolves it within the chroot.
      '';
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf authorizedKeyType;
      default = [ ];
      description = ''
        Public SSH keys for the pi-backup hosts allowed to pull. Each
        becomes a forced-command authorized_keys entry on root, restricted
        to `rrsync -ro <chrootRoot>`. The `restrict` keyword disables
        shell, port-forwarding, X11 and agent access; rrsync further
        locks the key to a single read-only rsync invocation rooted at
        the chroot.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Pre-create the chroot root and a mountpoint per source so the bind
    # mounts have somewhere to attach. systemd-tmpfiles-setup runs before
    # local-fs.target, so the mountpoints exist by the time fileSystems
    # mounts.
    systemd.tmpfiles.rules = [
      "d ${cfg.chrootRoot} 0755 root root - -"
    ]
    ++ lib.mapAttrsToList (name: _src: "d ${cfg.chrootRoot}/${name} 0755 root root - -") cfg.sources;

    fileSystems = mountUnits;

    # rrsync runs as root because some bind-mounted trees contain files
    # owned by container runtime UIDs (e.g. k3s PVC contents owned by
    # 1000:1000) that an unprivileged user cannot read. Forced-command +
    # `restrict` still locks each key to a single read-only rsync.
    users.users.root.openssh.authorizedKeys.keys = map (
      k: ''command="${pkgs.rsync}/bin/rrsync -ro ${cfg.chrootRoot}",restrict ${k.key} ${k.name}''
    ) cfg.authorizedKeys;
  };
}

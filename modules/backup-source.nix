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
in
{
  options.services.backup-source = {
    enable = lib.mkEnableOption "expose a read-only rsync path to one or more pi-backup hosts";

    allowedPath = lib.mkOption {
      type = lib.types.path;
      example = "/var/backups/bitwarden";
      description = ''
        Directory the `backup-pull` user is allowed to read via rrsync.
        rrsync's `-ro` flag pins the user to read-only and chroots the visible
        tree to this path.
      '';
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf authorizedKeyType;
      default = [ ];
      description = ''
        Public SSH keys for the pi-backup hosts allowed to pull. Each key is
        wrapped in a forced-command authorized_keys entry restricting it to
        `rrsync -ro <allowedPath>` with the standard hardening flags.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.backup-pull = {
      isSystemUser = true;
      group = "backup-pull";
      shell = pkgs.bashInteractive; # rrsync runs as the login shell command
      home = "/var/empty";
      createHome = false;
      # Forced-command authorized keys: each Pi gets one entry locked to rrsync -ro.
      # `restrict` disables pty/forwarding/X11/agent; rrsync ships with rsync.
      openssh.authorizedKeys.keys = map (
        e:
        ''command="${pkgs.rsync}/bin/rrsync -ro ${cfg.allowedPath}",restrict ${e.key} ${e.name}''
      ) cfg.authorizedKeys;
    };

    users.groups.backup-pull = { };

    # The allowed root must exist with the rrsync user as group owner, so the
    # forced-command rsync can traverse and read it.
    #
    # `d` only sets ownership at creation; another module may already create
    # the same path with different owners (e.g. modules/homelab/storage.nix).
    # The accompanying `z` line enforces 0750 root:backup-pull on each boot
    # whether the path is new or pre-existing.
    systemd.tmpfiles.rules = [
      "d ${cfg.allowedPath} 0750 root backup-pull - -"
      "z ${cfg.allowedPath} 0750 root backup-pull - -"
    ];
  };
}

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.bitwarden-dump;

  dumpScript = pkgs.writeShellApplication {
    name = "bitwarden-dump";
    runtimeInputs = with pkgs; [
      coreutils
      kubectl
      zstd
      gnutar
      findutils
    ];
    text = builtins.readFile ./bitwarden-dump.sh;
  };
in
{
  options.services.bitwarden-dump = {
    enable = lib.mkEnableOption "Bitwarden self-host disaster-recovery dump (postgres + PVCs)";

    outputDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/backups/bitwarden";
      description = "Where the timestamped dump pairs are written.";
    };

    kubeconfig = lib.mkOption {
      type = lib.types.path;
      default = "/etc/rancher/k3s/k3s.yaml";
      description = "k3s kubeconfig path. Default fits a k3s server install.";
    };

    namespace = lib.mkOption {
      type = lib.types.str;
      default = "bitwarden";
    };

    postgresPod = lib.mkOption {
      type = lib.types.str;
      default = "bitwarden-postgresql-0";
      description = "Name of the postgres pod inside `namespace`.";
    };

    postgresUser = lib.mkOption {
      type = lib.types.str;
      default = "bitwarden";
    };

    postgresDatabase = lib.mkOption {
      type = lib.types.str;
      default = "vault";
    };

    postgresAuthSecret = lib.mkOption {
      type = lib.types.str;
      default = "bitwarden-postgresql-auth";
      description = ''
        Name of the kubernetes Secret holding the postgres credentials.
        The dump script reads the `password` key (Bitnami chart convention).
      '';
    };

    pvcStorageRoot = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/rancher/k3s/storage";
      description = "Where the local-path provisioner stores PVC contents.";
    };

    keepDumps = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = "Local retention (number of dump pairs). Pis hold the long history.";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 03:00:00";
      description = "systemd OnCalendar expression. Should fire before the Pi pull window.";
    };
  };

  config = lib.mkIf cfg.enable {
    # The dump unit runs as root and writes the dir; rrsync also reads as
    # root via the backup-source bind mount. No other user touches it.
    systemd.tmpfiles.rules = [
      "d ${cfg.outputDir} 0700 root root - -"
      "z ${cfg.outputDir} 0700 root root - -"
    ];

    systemd.services.bitwarden-dump = {
      description = "Dump Bitwarden self-host for off-host pull backup";

      # Don't fire kubectl until the API server is up. A persistent timer
      # firing on early boot would otherwise spam a failure for nothing.
      after = [
        "k3s.service"
        "network-online.target"
      ];
      wants = [ "network-online.target" ];
      requires = [ "k3s.service" ];

      environment = {
        KUBECONFIG = cfg.kubeconfig;
        OUT_DIR = cfg.outputDir;
        NS = cfg.namespace;
        PG_POD = cfg.postgresPod;
        PG_USER = cfg.postgresUser;
        PG_DB = cfg.postgresDatabase;
        PG_AUTH_SECRET = cfg.postgresAuthSecret;
        PVC_ROOT = cfg.pvcStorageRoot;
        KEEP = toString cfg.keepDumps;
      };

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${dumpScript}/bin/bitwarden-dump";
        # k3s.yaml is root-readable by default; the unit needs that and the PVC tree.
        ReadOnlyPaths = [
          cfg.kubeconfig
          cfg.pvcStorageRoot
        ];
        ReadWritePaths = [ cfg.outputDir ];
        PrivateTmp = true;
        ProtectHome = true;
        NoNewPrivileges = true;
      };
    };

    systemd.timers.bitwarden-dump = {
      description = "Schedule for Bitwarden disaster-recovery dump";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = "5min";
      };
    };
  };
}

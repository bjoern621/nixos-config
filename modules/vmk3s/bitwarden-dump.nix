{
  config,
  lib,
  pkgs,
  ...
}:

# Bitwarden postgres logical dump for off-host pull backup. Writes a
# single `postgres.dump` (replaced atomically each run) into `outputDir`.
# The Pi snapshots provide the time-series history.

let
  cfg = config.services.bitwarden-dump;

  dumpScript = pkgs.writeShellApplication {
    name = "bitwarden-dump";
    runtimeInputs = with pkgs; [
      coreutils
      kubectl
    ];
    text = builtins.readFile ./bitwarden-dump.sh;
  };
in
{
  options.services.bitwarden-dump = {
    enable = lib.mkEnableOption "Bitwarden postgres logical dump";

    outputDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/backups/bitwarden";
    };

    kubeconfig = lib.mkOption {
      type = lib.types.path;
      default = "/etc/rancher/k3s/k3s.yaml";
    };

    namespace = lib.mkOption {
      type = lib.types.str;
      default = "bitwarden";
    };

    postgresPod = lib.mkOption {
      type = lib.types.str;
      default = "bitwarden-postgresql-0";
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
      description = "kube Secret name. The dump script reads its `password` key.";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 03:00:00";
      description = "systemd OnCalendar expression. Fires before the Pi pull window.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.outputDir} 0700 root root - -"
      "z ${cfg.outputDir} 0700 root root - -"
    ];

    systemd.services.bitwarden-dump = {
      description = "Dump Bitwarden postgres for off-host pull backup";

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
      };

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${dumpScript}/bin/bitwarden-dump";
        ReadOnlyPaths = [ cfg.kubeconfig ];
        ReadWritePaths = [ cfg.outputDir ];
        PrivateTmp = true;
        ProtectHome = true;
        NoNewPrivileges = true;
      };
    };

    systemd.timers.bitwarden-dump = {
      description = "Schedule for Bitwarden postgres dump";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = "5min";
      };
    };
  };
}

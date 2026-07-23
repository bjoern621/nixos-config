{
  config,
  lib,
  pkgs,
  ...
}:

# Node-local observability stack: VictoriaMetrics, VictoriaLogs,
# VictoriaTraces and Grafana. Ingest ports and Grafana reachable over the
# tailnet only; local collector pushes via loopback. Mirrors the vmk3s
# in-cluster stack (hh-cluster-infra argocd/applications/observability).

let
  cfg = config.services.victoria-stack;
in
{
  options.services.victoria-stack = {
    enable = lib.mkEnableOption "local VictoriaMetrics/Logs/Traces + Grafana stack";

    retention = lib.mkOption {
      type = lib.types.str;
      default = "14d";
      description = "Retention period applied to all three stores.";
    };

    logsMaxDiskUsage = lib.mkOption {
      type = lib.types.str;
      default = "10GiB";
      description = "Disk cap for VictoriaLogs. Second safety net besides time retention; a log flood otherwise fills the disk.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.victoriametrics = {
      enable = true;
      listenAddress = ":8428";
      retentionPeriod = cfg.retention;
    };

    services.victorialogs = {
      enable = true;
      listenAddress = ":9428";
      extraOptions = [
        "-retentionPeriod=${cfg.retention}"
        "-retention.maxDiskSpaceUsageBytes=${cfg.logsMaxDiskUsage}"
      ];
    };

    services.victoriatraces = {
      enable = true;
      listenAddress = ":10428";
      retentionPeriod = cfg.retention;
    };

    services.grafana = {
      enable = true;
      declarativePlugins = with pkgs.grafanaPlugins; [
        victoriametrics-metrics-datasource
        victoriametrics-logs-datasource
      ];
      settings.server = {
        http_addr = "0.0.0.0";
        http_port = 3000;
      };
      # Module refuses Grafana's built-in default secret_key. Key generated
      # once on first start, never in the repo. Encrypts datasource secrets
      # in the Grafana DB; losing it only invalidates stored credentials,
      # and the provisioned datasources carry none.
      settings.security.secret_key = "$__file{/var/lib/grafana/secret_key}";
      provision = {
        enable = true;
        # Uids match the vmk3s in-cluster Grafana so the same dashboard
        # JSON works against both.
        datasources.settings = {
          apiVersion = 1;
          # Grafana cannot change the uid of an already provisioned
          # datasource in place ("data source not found" at boot). Delete by
          # name first; idempotent, datasources are fully re-provisioned.
          deleteDatasources = [
            {
              name = "VictoriaMetrics";
              orgId = 1;
            }
            {
              name = "VictoriaLogs";
              orgId = 1;
            }
            {
              name = "VictoriaTraces";
              orgId = 1;
            }
          ];
          datasources = [
            {
              name = "VictoriaMetrics";
              uid = "victoriametrics";
              type = "victoriametrics-metrics-datasource";
              access = "proxy";
              url = "http://127.0.0.1:8428";
              isDefault = true;
            }
            {
              name = "VictoriaLogs";
              uid = "victorialogs";
              type = "victoriametrics-logs-datasource";
              access = "proxy";
              url = "http://127.0.0.1:9428";
            }
            # victoria-traces serves a Jaeger-compatible query API under
            # /select/jaeger. Core Jaeger datasource works unmodified.
            {
              name = "VictoriaTraces";
              uid = "victoriatraces";
              type = "jaeger";
              access = "proxy";
              url = "http://127.0.0.1:10428/select/jaeger";
            }
          ];
        };
        # Dashboards mirror the in-cluster Grafana. Canonical copies live in
        # hh-cluster-infra (argocd/applications/observability/manifests/
        # dashboards); the files in ./dashboards are synced copies.
        dashboards.settings = {
          apiVersion = 1;
          providers = [
            {
              name = "default";
              type = "file";
              allowUiUpdates = false;
              options.path = ./dashboards;
              options.foldersFromFilesStructure = false;
            }
          ];
        };
      };
    };

    systemd.services.grafana.preStart = ''
      if [ ! -f /var/lib/grafana/secret_key ]; then
        (umask 077; ${pkgs.coreutils}/bin/head -c 32 /dev/urandom | ${pkgs.coreutils}/bin/base64 -w0 > /var/lib/grafana/secret_key)
      fi
    '';

    # Ingest (8428/9428/10428) for remote collectors and Grafana (3000) for
    # admins, tailnet only. LAN stays closed.
    networking.firewall.interfaces."tailscale0".allowedTCPPorts = [
      3000
      8428
      9428
      10428
    ];
  };
}

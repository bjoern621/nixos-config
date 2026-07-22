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
      provision = {
        enable = true;
        datasources.settings = {
          apiVersion = 1;
          datasources = [
            {
              name = "VictoriaMetrics";
              type = "victoriametrics-metrics-datasource";
              access = "proxy";
              url = "http://127.0.0.1:8428";
              isDefault = true;
            }
            {
              name = "VictoriaLogs";
              type = "victoriametrics-logs-datasource";
              access = "proxy";
              url = "http://127.0.0.1:9428";
            }
            # victoria-traces serves a Jaeger-compatible query API under
            # /select/jaeger. Core Jaeger datasource works unmodified.
            {
              name = "VictoriaTraces";
              type = "jaeger";
              access = "proxy";
              url = "http://127.0.0.1:10428/select/jaeger";
            }
          ];
        };
      };
    };

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

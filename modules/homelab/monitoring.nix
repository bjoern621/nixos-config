{ ... }:

# Collector-only host per the observability architecture: no local stores,
# no Grafana. Telemetry pushes over the tailnet to the vmk3s in-cluster
# stack and the pi-4b-hh stack. Grafana on either target shows this host.

{
  imports = [ ../telemetry-agent.nix ];

  services.telemetry-agent = {
    enable = true;

    # Docker runs workloads here; per-container CPU/mem/net via docker_stats.
    dockerStats = true;

    stacks = {
      vmk3s = {
        metricsUrl = "http://victoria-metrics-vmk3s.tail115f30.ts.net:8428/api/v1/write";
        logsUrl = "http://victoria-logs-vmk3s.tail115f30.ts.net:9428/insert/opentelemetry/v1/logs";
        tracesUrl = "http://victoria-traces-vmk3s.tail115f30.ts.net:10428/insert/opentelemetry/v1/traces";
      };
      pi-hh = {
        metricsUrl = "http://pi-4b-hh.tail115f30.ts.net:8428/api/v1/write";
        logsUrl = "http://pi-4b-hh.tail115f30.ts.net:9428/insert/opentelemetry/v1/logs";
        tracesUrl = "http://pi-4b-hh.tail115f30.ts.net:10428/insert/opentelemetry/v1/traces";
      };
    };

    scrapeConfigs = [
      {
        job_name = "smartctl";
        static_configs = [ { targets = [ "127.0.0.1:9633" ]; } ];
      }
      {
        job_name = "libvirt";
        static_configs = [ { targets = [ "127.0.0.1:9177" ]; } ];
      }
    ];
  };

  # Disk health for the storage pool drives.
  services.prometheus.exporters.smartctl = {
    enable = true;
    listenAddress = "127.0.0.1";
  };

  # Per-VM CPU/mem/block/net from libvirt (vmk3s VM visible from outside).
  # qemu:///system socket is group libvirtd.
  services.prometheus.exporters.libvirt = {
    enable = true;
    listenAddress = "127.0.0.1";
    group = "libvirtd";
  };

  # Docker default json-file driver bypasses journald; without this the
  # collector never sees container logs.
  virtualisation.docker.logDriver = "journald";
}

{ ... }:

let
  grafanaDatasources = builtins.fromJSON (builtins.readFile ./monitoring/grafana-datasources.json);
  grafanaDashboardProviders = builtins.fromJSON (builtins.readFile ./monitoring/grafana-dashboard-providers.json);
in

{
  services.prometheus = {
    enable = true;
    listenAddress = "0.0.0.0";
    port = 9090;

    exporters.node = {
      enable = true;
      enabledCollectors = [
        "systemd"
      ];
    };

    globalConfig = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
    };

    scrapeConfigs = [
      {
        job_name = "prometheus";
        static_configs = [
          {
            targets = [ "127.0.0.1:9090" ];
          }
        ];
      }
      {
        job_name = "homelab-node";
        static_configs = [
          {
            targets = [ "127.0.0.1:9100" ];
          }
        ];
      }
    ];
  };

  services.grafana = {
    enable = true;
    provision = {
      enable = true;
      datasources.settings = grafanaDatasources;
      dashboards.settings = grafanaDashboardProviders;
    };
    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = 3000;
      };
      security = {
        # Default key. Grafana still requires a stable secret_key to encrypt data source and other stored secrets.
        secret_key = "SW2YcwTIb9zpOOhoPsMm";
      };
    };
  };

  environment.etc."grafana-dashboards/homelab-health.json".source = ./monitoring/homelab-health-dashboard.json;

  networking.firewall.allowedTCPPorts = [
    3000 # Grafana UI
    9090 # Prometheus UI
  ];
}

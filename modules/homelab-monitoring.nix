{ ... }:

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
      datasources.settings = {
        apiVersion = 1;
        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://127.0.0.1:9090";
            isDefault = true;
            editable = false;
          }
        ];
      };
      dashboards.settings = {
        apiVersion = 1;
        providers = [
          {
            name = "homelab";
            orgId = 1;
            folder = "Homelab";
            type = "file";
            disableDeletion = false;
            editable = true;
            options = {
              path = "/etc/grafana-dashboards";
            };
          }
        ];
      };
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

  environment.etc."grafana-dashboards/homelab-health.json".text = builtins.toJSON {
    annotations = {
      list = [
        {
          builtIn = 1;
          datasource = {
            type = "grafana";
            uid = "-- Grafana --";
          };
          enable = true;
          hide = true;
          iconColor = "rgba(0, 211, 255, 1)";
          name = "Annotations & Alerts";
          type = "dashboard";
        }
      ];
    };
    editable = true;
    graphTooltip = 1;
    panels = [
      {
        datasource = "Prometheus";
        fieldConfig.defaults = {
          color.mode = "thresholds";
          max = 1;
          min = 0;
          thresholds = {
            mode = "absolute";
            steps = [
              {
                color = "red";
                value = 0;
              }
              {
                color = "green";
                value = 1;
              }
            ];
          };
          unit = "none";
        };
        gridPos = {
          h = 4;
          w = 4;
          x = 0;
          y = 0;
        };
        id = 1;
        options = {
          colorMode = "value";
          graphMode = "none";
          justifyMode = "center";
          orientation = "horizontal";
          reduceOptions = {
            calcs = [ "lastNotNull" ];
            fields = "";
            values = false;
          };
          textMode = "auto";
        };
        targets = [
          {
            expr = "up{job=\"homelab-node\"}";
            instant = true;
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
        title = "Node Up";
        type = "stat";
      }
      {
        datasource = "Prometheus";
        fieldConfig.defaults = {
          color.mode = "thresholds";
          max = 100;
          min = 0;
          thresholds = {
            mode = "absolute";
            steps = [
              {
                color = "green";
                value = 0;
              }
              {
                color = "orange";
                value = 70;
              }
              {
                color = "red";
                value = 90;
              }
            ];
          };
          unit = "percent";
        };
        gridPos = {
          h = 4;
          w = 4;
          x = 4;
          y = 0;
        };
        id = 2;
        options = {
          colorMode = "background";
          graphMode = "area";
          justifyMode = "center";
          orientation = "horizontal";
          reduceOptions = {
            calcs = [ "lastNotNull" ];
            fields = "";
            values = false;
          };
          textMode = "auto";
        };
        targets = [
          {
            expr = "100 * (1 - avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])))";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
        title = "CPU Usage";
        type = "stat";
      }
      {
        datasource = "Prometheus";
        fieldConfig.defaults = {
          color.mode = "thresholds";
          max = 100;
          min = 0;
          thresholds = {
            mode = "absolute";
            steps = [
              {
                color = "green";
                value = 0;
              }
              {
                color = "orange";
                value = 75;
              }
              {
                color = "red";
                value = 90;
              }
            ];
          };
          unit = "percent";
        };
        gridPos = {
          h = 4;
          w = 4;
          x = 8;
          y = 0;
        };
        id = 3;
        options = {
          colorMode = "background";
          graphMode = "area";
          justifyMode = "center";
          orientation = "horizontal";
          reduceOptions = {
            calcs = [ "lastNotNull" ];
            fields = "";
            values = false;
          };
          textMode = "auto";
        };
        targets = [
          {
            expr = "100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
        title = "Memory Usage";
        type = "stat";
      }
      {
        datasource = "Prometheus";
        fieldConfig.defaults = {
          color.mode = "thresholds";
          max = 100;
          min = 0;
          thresholds = {
            mode = "absolute";
            steps = [
              {
                color = "green";
                value = 0;
              }
              {
                color = "orange";
                value = 75;
              }
              {
                color = "red";
                value = 90;
              }
            ];
          };
          unit = "percent";
        };
        gridPos = {
          h = 4;
          w = 4;
          x = 12;
          y = 0;
        };
        id = 4;
        options = {
          colorMode = "background";
          graphMode = "area";
          justifyMode = "center";
          orientation = "horizontal";
          reduceOptions = {
            calcs = [ "lastNotNull" ];
            fields = "";
            values = false;
          };
          textMode = "auto";
        };
        targets = [
          {
            expr = "100 * (1 - (node_filesystem_avail_bytes{mountpoint=\"/\",fstype!~\"tmpfs|overlay\"} / node_filesystem_size_bytes{mountpoint=\"/\",fstype!~\"tmpfs|overlay\"}))";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
        title = "Root FS Usage";
        type = "stat";
      }
      {
        datasource = "Prometheus";
        fieldConfig.defaults = {
          color.mode = "palette-classic";
          unit = "short";
        };
        gridPos = {
          h = 8;
          w = 8;
          x = 0;
          y = 4;
        };
        id = 5;
        options = {
          legend = {
            calcs = [ ];
            displayMode = "table";
            placement = "bottom";
            showLegend = true;
          };
          tooltip = {
            mode = "multi";
            sort = "none";
          };
        };
        targets = [
          {
            expr = "node_load1";
            legendFormat = "{{instance}} load1";
            refId = "A";
          }
          {
            expr = "node_load5";
            legendFormat = "{{instance}} load5";
            refId = "B";
          }
          {
            expr = "node_load15";
            legendFormat = "{{instance}} load15";
            refId = "C";
          }
        ];
        title = "System Load";
        type = "timeseries";
      }
      {
        datasource = "Prometheus";
        fieldConfig.defaults = {
          color.mode = "palette-classic";
          unit = "binBps";
        };
        gridPos = {
          h = 8;
          w = 8;
          x = 8;
          y = 4;
        };
        id = 6;
        options = {
          legend = {
            calcs = [ ];
            displayMode = "table";
            placement = "bottom";
            showLegend = true;
          };
          tooltip = {
            mode = "multi";
            sort = "none";
          };
        };
        targets = [
          {
            expr = "sum by(instance) (rate(node_network_receive_bytes_total{device!~\"lo\"}[5m]))";
            legendFormat = "{{instance}} rx";
            refId = "A";
          }
          {
            expr = "sum by(instance) (rate(node_network_transmit_bytes_total{device!~\"lo\"}[5m]))";
            legendFormat = "{{instance}} tx";
            refId = "B";
          }
        ];
        title = "Network Throughput";
        type = "timeseries";
      }
      {
        datasource = "Prometheus";
        fieldConfig.defaults = {
          color.mode = "palette-classic";
          unit = "percent";
        };
        gridPos = {
          h = 8;
          w = 8;
          x = 16;
          y = 4;
        };
        id = 7;
        options = {
          legend = {
            calcs = [ ];
            displayMode = "table";
            placement = "bottom";
            showLegend = true;
          };
          tooltip = {
            mode = "multi";
            sort = "none";
          };
        };
        targets = [
          {
            expr = "100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))";
            legendFormat = "{{instance}} memory";
            refId = "A";
          }
          {
            expr = "100 * (1 - avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])))";
            legendFormat = "{{instance}} cpu";
            refId = "B";
          }
          {
            expr = "100 * (1 - (node_filesystem_avail_bytes{mountpoint=\"/\",fstype!~\"tmpfs|overlay\"} / node_filesystem_size_bytes{mountpoint=\"/\",fstype!~\"tmpfs|overlay\"}))";
            legendFormat = "{{instance}} rootfs";
            refId = "C";
          }
        ];
        title = "Resource Pressure";
        type = "timeseries";
      }
    ];
    refresh = "15s";
    schemaVersion = 39;
    style = "dark";
    tags = [
      "homelab"
      "prometheus"
      "health"
    ];
    templating = {
      list = [ ];
    };
    time = {
      from = "now-6h";
      to = "now";
    };
    title = "Homelab Health";
    uid = "homelab-health";
    version = 1;
  };

  networking.firewall.allowedTCPPorts = [
    3000 # Grafana UI
    9090 # Prometheus UI
  ];
}

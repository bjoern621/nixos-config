{
  config,
  lib,
  pkgs,
  ...
}:

# Host-level OpenTelemetry collector agent. Pulls journald + hostmetrics,
# accepts OTLP from local apps, pushes to one or more Victoria stacks
# (fan-out per `stacks`). Persistent sending queues under
# /var/lib/opentelemetry-collector survive restarts and offline targets.

let
  cfg = config.services.telemetry-agent;

  metricsExporters = lib.mapAttrs' (
    name: stack:
    lib.nameValuePair "prometheusremotewrite/${name}" {
      endpoint = stack.metricsUrl;
      # Without this only job and instance survive as labels; host.name dies.
      resource_to_telemetry_conversion.enabled = true;
    }
  ) cfg.stacks;

  logsExporters = lib.mapAttrs' (
    name: stack:
    lib.nameValuePair "otlphttp/${name}-logs" {
      logs_endpoint = stack.logsUrl;
      # Explicit stream fields. VictoriaLogs otherwise streams on every
      # resource attribute, so churny attributes multiply streams.
      headers."VL-Stream-Fields" = "host.name,unit,container.name";
      sending_queue = {
        enabled = true;
        storage = "file_storage";
      };
    }
  ) cfg.stacks;

  # Collector-to-collector forward (standard OTLP paths derive from the base
  # endpoint). Used by hosts that feed another collector instead of stores.
  forwardExporter = lib.optionalAttrs (cfg.otlpForward != null) {
    "otlphttp/forward" = {
      endpoint = cfg.otlpForward;
      sending_queue = {
        enabled = true;
        storage = "file_storage";
      };
    };
  };

  tracedStacks = lib.filterAttrs (_: stack: stack.tracesUrl != null) cfg.stacks;

  tracesExporters = lib.mapAttrs' (
    name: stack:
    lib.nameValuePair "otlphttp/${name}-traces" {
      traces_endpoint = stack.tracesUrl;
      sending_queue = {
        enabled = true;
        storage = "file_storage";
      };
    }
  ) tracedStacks;
in
{
  options.services.telemetry-agent = {
    enable = lib.mkEnableOption "OpenTelemetry collector agent pushing to Victoria stacks";

    stacks = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            metricsUrl = lib.mkOption {
              type = lib.types.str;
              example = "http://victoria-metrics-vmk3s.tail115f30.ts.net:8428/api/v1/write";
              description = "Prometheus remote write endpoint of the stack's VictoriaMetrics.";
            };
            logsUrl = lib.mkOption {
              type = lib.types.str;
              example = "http://victoria-logs-vmk3s.tail115f30.ts.net:9428/insert/opentelemetry/v1/logs";
              description = "OTLP/HTTP logs endpoint of the stack's VictoriaLogs.";
            };
            tracesUrl = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              example = "http://victoria-traces-vmk3s.tail115f30.ts.net:10428/insert/opentelemetry/v1/traces";
              description = "OTLP/HTTP traces endpoint of the stack's VictoriaTraces. `null` -> no traces to this stack.";
            };
          };
        }
      );
      default = { };
      description = "Victoria stacks to push to. Attr name becomes the exporter name suffix.";
    };

    otlpListenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Bind address for the OTLP receiver (ports 4317 gRPC, 4318 HTTP).";
    };

    otlpForward = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "http://127.0.0.1:30318";
      description = "OTLP/HTTP base endpoint of another collector to forward all signals to. Alternative or addition to `stacks`.";
    };

    hostMetrics = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Collect hostmetrics. Off where another collector already reports this machine (vmk3s: the DaemonSet's hostmetrics against the node root).";
    };

    scrapeConfigs = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      example = lib.literalExpression ''
        [
          {
            job_name = "smartctl";
            static_configs = [ { targets = [ "127.0.0.1:9633" ]; } ];
          }
        ]
      '';
      description = "Extra Prometheus scrape configs for local exporters.";
    };

    dockerStats = lib.mkEnableOption "per-container metrics via the docker_stats receiver";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.stacks != { } || cfg.otlpForward != null;
        message = "services.telemetry-agent: set `stacks`, `otlpForward` or both; the agent needs somewhere to push.";
      }
    ];

    services.opentelemetry-collector = {
      enable = true;
      # journald and hostmetrics receivers live in contrib only.
      package = pkgs.opentelemetry-collector-contrib;

      settings = {
        extensions = {
          health_check.endpoint = "127.0.0.1:13133";
          # Backs the persistent sending queues. StateDirectory creates the
          # directory; create_directory would fail under ProtectSystem.
          file_storage = {
            directory = "/var/lib/opentelemetry-collector";
            create_directory = false;
          };
        };

        receivers = {
          journald = {
            operators = [
              # Journal entry arrives as field map in body. Hoist the useful
              # fields, then reduce body to the message string; a map body
              # would leave VictoriaLogs without a usable _msg.
              {
                type = "move";
                "if" = ''body["_SYSTEMD_UNIT"] != nil'';
                from = "body._SYSTEMD_UNIT";
                to = "attributes.unit";
              }
              {
                type = "move";
                "if" = ''body["SYSLOG_IDENTIFIER"] != nil'';
                from = "body.SYSLOG_IDENTIFIER";
                to = "attributes.syslog_identifier";
              }
              {
                type = "move";
                "if" = ''body["PRIORITY"] != nil'';
                from = "body.PRIORITY";
                to = "attributes.priority";
              }
              # Set by docker's journald log driver (virtualisation.docker.logDriver).
              {
                type = "move";
                "if" = ''body["CONTAINER_NAME"] != nil'';
                from = "body.CONTAINER_NAME";
                to = ''attributes["container.name"]'';
              }
              # syslog priority: 0-3 error, 4 warn, 5-6 info, 7 debug.
              {
                type = "severity_parser";
                "if" = ''attributes["priority"] != nil'';
                parse_from = "attributes.priority";
                mapping = {
                  error = [ "0" "1" "2" "3" ];
                  warn = [ "4" ];
                  info = [ "5" "6" ];
                  debug = [ "7" ];
                };
              }
              {
                type = "move";
                "if" = ''body["MESSAGE"] != nil'';
                from = "body.MESSAGE";
                to = "body";
              }
              # dbus-broker-launch reports XDG service-file shadowing at err
              # priority on every activation. The duplicates are the stock
              # NixOS layout (system-path beside per-package dirs), so the
              # noise is permanent and drowns the error-level view.
              {
                type = "filter";
                expr = ''attributes["syslog_identifier"] == "dbus-broker-launch" and body matches "^Ignoring duplicate name"'';
              }
            ];
          };

        }
        // lib.optionalAttrs cfg.hostMetrics {
          hostmetrics = {
            collection_interval = "30s";
            scrapers = {
              cpu = { };
              load = { };
              memory = { };
              disk = { };
              network = { };
              filesystem = {
                exclude_fs_types = {
                  match_type = "strict";
                  fs_types = [
                    "overlay"
                    "squashfs"
                    "tmpfs"
                  ];
                };
                exclude_mount_points = {
                  match_type = "regexp";
                  mount_points = [
                    "/run/.*"
                    "/nix/store"
                  ];
                };
              };
            };
          };
        }
        // {
          otlp.protocols = {
            grpc.endpoint = "${cfg.otlpListenAddress}:4317";
            http.endpoint = "${cfg.otlpListenAddress}:4318";
          };

          # Own telemetry (localhost:8888) plus local exporters.
          prometheus.config.scrape_configs = [
            {
              job_name = "otel-collector";
              scrape_interval = "30s";
              static_configs = [ { targets = [ "127.0.0.1:8888" ]; } ];
            }
          ]
          ++ cfg.scrapeConfigs;
        }
        // lib.optionalAttrs cfg.dockerStats {
          docker_stats = {
            endpoint = "unix:///var/run/docker.sock";
            collection_interval = "30s";
          };
        };

        processors = {
          memory_limiter = {
            check_interval = "1s";
            limit_mib = 400;
            spike_limit_mib = 100;
          };
          # Same-named series from different hosts collide without this.
          "resource/host".attributes = [
            {
              key = "host.name";
              value = config.networking.hostName;
              action = "upsert";
            }
          ];
          batch.timeout = "5s";
        };

        exporters = metricsExporters // logsExporters // tracesExporters // forwardExporter;

        service = {
          extensions = [
            "health_check"
            "file_storage"
          ];
          telemetry.metrics = {
            level = "normal";
            readers = [
              {
                pull.exporter.prometheus = {
                  host = "127.0.0.1";
                  port = 8888;
                };
              }
            ];
          };
          pipelines = {
            metrics = {
              receivers = [
                "prometheus"
                "otlp"
              ]
              ++ lib.optional cfg.hostMetrics "hostmetrics"
              ++ lib.optional cfg.dockerStats "docker_stats";
              processors = [
                "memory_limiter"
                "resource/host"
                "batch"
              ];
              exporters = lib.attrNames (metricsExporters // forwardExporter);
            };
            logs = {
              receivers = [
                "journald"
                "otlp"
              ];
              processors = [
                "memory_limiter"
                "resource/host"
                "batch"
              ];
              exporters = lib.attrNames (logsExporters // forwardExporter);
            };
          }
          // lib.optionalAttrs (tracedStacks != { } || cfg.otlpForward != null) {
            traces = {
              receivers = [ "otlp" ];
              processors = [
                "memory_limiter"
                "batch"
              ];
              exporters = lib.attrNames (tracesExporters // forwardExporter);
            };
          };
        };
      };
    };

    systemd.services.opentelemetry-collector = {
      # journald receiver execs journalctl.
      path = [ pkgs.systemd ];
      # Soft limit below memory_limiter hard limit. GC pressure before refusal.
      environment.GOMEMLIMIT = "350MiB";
      serviceConfig.SupplementaryGroups = lib.mkIf cfg.dockerStats [ "docker" ];
    };
  };
}

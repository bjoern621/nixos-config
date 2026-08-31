{
  config,
  lib,
  inputs,
  ...
}:

# Exports the nixos-config revision the running system was built from as a
# metric. The fleet badge endpoint (hh-cluster-infra, status-proxy
# application) compares it against origin/main and renders the README chips.

let
  cfg = config.services.sysconf-revision;

  self = inputs.self;

  # sysconf-reload copies hardware-configuration.nix into the tree and runs
  # `git add -N .`, so a routine deploy can evaluate as dirty. dirtyRev still
  # carries HEAD as "<sha>-dirty"; the flag keeps the uncertainty visible.
  dirty = !(self ? rev);
  rev = if !dirty then self.rev else lib.removeSuffix "-dirty" (self.dirtyRev or "unknown");
in
{
  # Option must exist even where the host enables no agent; the exporter then
  # serves localhost and nothing scrapes it.
  imports = [ ./telemetry-agent.nix ];

  options.services.sysconf-revision = {
    enable = lib.mkEnableOption "installed-revision metric for the fleet badges";
  };

  config = lib.mkIf cfg.enable {
    system.configurationRevision = lib.mkIf (rev != "unknown") rev;

    # Textfile collector only. Machine stats come from the telemetry agent.
    services.prometheus.exporters.node = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9100;
      extraFlags = [
        "--collector.disable-defaults"
        "--collector.textfile.directory=/etc/sysconf-metrics"
      ];
      enabledCollectors = [ "textfile" ];
    };

    # Value: commit time of HEAD. Eval time on a dirty tree, so the badge
    # endpoint resolves the exact time by sha and reads this only as fallback.
    environment.etc."sysconf-metrics/sysconf.prom".text = ''
      # TYPE sysconf_installed_commit_time_seconds gauge
      sysconf_installed_commit_time_seconds{revision="${rev}",dirty="${lib.boolToString dirty}"} ${toString (self.lastModified or 0)}
    '';

    # switch-to-configuration only diffs units it sees as active, and starts
    # new units by restarting active targets. On a host whose
    # multi-user.target has gone inactive neither path runs, and the exporter
    # stays dead after every switch. The activation list bypasses both:
    # listed units start when inactive and restart when active.
    system.activationScripts.sysconf-revision = {
      supportsDryActivation = true;
      text = ''
        mkdir -p /run/nixos
        if [ "$NIXOS_ACTION" = dry-activate ]; then
          echo prometheus-node-exporter.service >> /run/nixos/dry-activation-restart-list
        else
          echo prometheus-node-exporter.service >> /run/nixos/activation-restart-list
        fi
      '';
    };

    services.telemetry-agent.scrapeConfigs = [
      {
        job_name = "sysconf";
        scrape_interval = "5m";
        static_configs = [ { targets = [ "127.0.0.1:9100" ]; } ];
      }
    ];
  };
}

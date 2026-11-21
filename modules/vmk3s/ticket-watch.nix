{
  config,
  lib,
  pkgs,
  ...
}:

# 40C3 ticket shop watcher. Alerts Discord when product turns buyable.
# Code, node_modules, webhook URL and browser profile sit in `directory`, copied there by hand.
# Module keeps process running, restarts it after crash.

let
  cfg = config.services.ticket-watch;
in
{
  options.services.ticket-watch = {
    enable = lib.mkEnableOption "40C3 ticket shop watcher";

    user = lib.mkOption {
      type = lib.types.str;
      default = "ops";
    };

    directory = lib.mkOption {
      type = lib.types.path;
      default = "/home/ops/ticket-watch";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.ticket-watch = {
      description = "40C3 ticket shop watcher";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment.MULLVAD_BROWSER = lib.getExe pkgs.mullvad-browser;

      serviceConfig = {
        User = cfg.user;
        WorkingDirectory = cfg.directory;
        ExecStart = "${lib.getExe pkgs.nodejs} ticket-watch.mjs";
        Restart = "always";
        RestartSec = "30s";
      };
    };
  };
}

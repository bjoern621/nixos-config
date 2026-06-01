{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.sysconf-auto-pull;
in
{
  options.services.sysconf-auto-pull = {
    enable = lib.mkEnableOption "periodic GitOps sync that runs sysconf-pull from origin";

    user = lib.mkOption {
      type = lib.types.str;
      example = "ops";
      description = ''
        User that owns the config repo and runs sysconf-pull. The user needs
        passwordless nixos-rebuild via services.sysconf-sudo.
      '';
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "systemd OnCalendar schedule for the sync.";
    };
  };

  config = lib.mkIf cfg.enable {
    # The host is a GitOps mirror: this timer pulls origin/main and rebuilds, so
    # the host converges to whatever is committed. Updates to flake inputs are
    # made centrally and land in git; the host never computes its own revisions.
    systemd.services.sysconf-auto-pull = {
      description = "Sync this host to origin/main via sysconf-pull";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
      };
      path = [
        pkgs.git
        pkgs.openssh
      ];
      script = ''
        export PATH=/run/wrappers/bin:/run/current-system/sw/bin:$PATH
        exec sysconf-pull
      '';
    };

    systemd.timers.sysconf-auto-pull = {
      description = "Timer for periodic sysconf-pull sync";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };
  };
}

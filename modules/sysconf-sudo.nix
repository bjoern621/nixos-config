{ config, lib, ... }:

let
  cfg = config.services.sysconf-sudo;
in
{
  options.services.sysconf-sudo.users = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [ "ops" ];
    description = ''
      Local accounts allowed to run `nixos-rebuild` via passwordless sudo, so
      the sysconf-* scripts (sysconf-pull, sysconf-reload, sysconf-update) can
      rebuild the system without an interactive password prompt.

      Only nixos-rebuild is granted root. The scripts run all git and file
      operations as the invoking user, so repository files stay owned by that
      user rather than drifting to root. The named users must already be
      declared elsewhere.
    '';
  };

  config = lib.mkIf (cfg.users != [ ]) {
    security.sudo.extraRules = [
      {
        users = cfg.users;
        commands = [
          {
            command = "/run/current-system/sw/bin/nixos-rebuild";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}

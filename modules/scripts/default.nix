{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.sysconf;
in
{
  imports = [
    ./sysconf-pull.nix
    ./sysconf-update.nix
    ./sysconf-reload.nix
    ./sysconf-help.nix
    ./sysconf-audio-fix.nix
    ./sysconf-fix-monitors.nix
    ./sysconf-selftest.nix
  ];

  options.sysconf = {
    user = lib.mkOption {
      type = lib.types.str;
      default = "root";
      example = "ops";
      description = ''
        Who rebuilds this machine, and therefore whose home holds the checkout.

        A machine reached as root alone leaves it at the default; one with an admin account
        names that account.
      '';
    };

    configPath = lib.mkOption {
      type = lib.types.str;
      default =
        if cfg.user == "root" then "/root/git/nixos-config" else "/home/${cfg.user}/git/nixos-config";
      defaultText = lib.literalExpression ''"~''${sysconf.user}/git/nixos-config"'';
      example = "/srv/nixos-config";
      description = ''
        Where this machine's checkout of this repository lives.

        Every sysconf-* command reads it: a pull fetches into it, a reload builds the host
        flake under it.
        It is a working tree somebody edits and pulls, so it sits in a home directory rather
        than under /etc.
      '';
    };
  };

  # The wrappers shell out to git and carry none of their own: a headless host has it from
  # here alone.
  config.environment.systemPackages = [ pkgs.git ];
}

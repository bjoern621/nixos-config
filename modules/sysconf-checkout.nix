# Puts this repository on the machine, so a host installed from an image or activated over ssh
# can rebuild itself: it has the closure and none of the source.
#
# Cloned from origin rather than copied from the deploying machine, which carries a closure and
# not a working tree, and whose copy would have no remote to pull from afterwards.
# What lands is origin's head, behind the deploying machine's tree whenever that tree has
# uncommitted edits.

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.sysconf.checkout;
in
{
  options.sysconf.checkout = {
    enable = lib.mkEnableOption "cloning this repository onto the machine on first activation";

    url = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/bjoern621/nixos-config.git";
      description = ''
        Where the checkout is cloned from.

        https rather than ssh, so the clone needs no key on a machine that has none. The
        repository is public; a private input it references is a separate credential, and the
        clone does not need it.
      '';
    };

    owner = lib.mkOption {
      type = lib.types.str;
      default = if config.sysconf.user == "root" then "root:root" else "${config.sysconf.user}:users";
      defaultText = lib.literalExpression ''"''${sysconf.user}:users"'';
      example = "ops:users";
      description = ''
        Who owns the checkout, as chown spells it.

        The clone runs as root and the sysconf-* commands run git as the invoking user, so
        this hands the working tree to whoever rebuilds the machine.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.sysconf-checkout = {
      description = "Clone the NixOS configuration repository onto this machine";
      wantedBy = [ "multi-user.target" ];
      # Both, because hosts here differ. A machine with scripted static networking reaches
      # network-online.target instantly and never waits on anything, so what orders the clone
      # after its address exists is network.target; a machine with a wait-online unit gets the
      # stronger guarantee from the second.
      after = [
        "network.target"
        "network-online.target"
      ];
      wants = [ "network-online.target" ];

      # Never runs twice: what updates the checkout after this is its own git remote.
      # A oneshot takes no Restart=, so a clone that failed for want of a network is retried by
      # the next activation.
      unitConfig.ConditionPathExists = "!${config.sysconf.configPath}/.git";

      path = [ pkgs.git ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        set -euo pipefail
        mkdir -p "$(dirname ${config.sysconf.configPath})"
        git clone ${cfg.url} ${config.sysconf.configPath}
        chown -R ${cfg.owner} ${config.sysconf.configPath}
      '';
    };
  };
}

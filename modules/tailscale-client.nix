{ config, lib, ... }:

let
  cfg = config.services.tailscale-client;
in
{
  options.services.tailscale-client = {
    operator = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        User passed to `tailscale up --operator=<user>` so they can use the
        Tailscale CLI without sudo. See
        https://tailscale.com/docs/reference/troubleshooting/linux/linux-operator-permission
        Default `null` -> no operator flag passed (suitable for headless hosts).
      '';
    };
  };

  config = {
    services.tailscale = {
      enable = true;
      extraSetFlags = lib.optional (cfg.operator != null) "--operator=${cfg.operator}";
    };
  };
}

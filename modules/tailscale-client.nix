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

    acceptDns = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether MagicDNS may take over `/etc/resolv.conf`.

        Off where another resolver on the host owns that file. A k3s node is the case:
        kubelet hands its own resolv.conf to CoreDNS, so a MagicDNS takeover moves every
        cluster lookup onto 100.100.100.100. Peers are then addressed by tailnet IP
        (lib/tailnet.nix) rather than by name.
      '';
    };
  };

  config = {
    services.tailscale = {
      enable = true;
      extraSetFlags =
        lib.optional (cfg.operator != null) "--operator=${cfg.operator}"
        ++ lib.optional (!cfg.acceptDns) "--accept-dns=false";
    };
  };
}

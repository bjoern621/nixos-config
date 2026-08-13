# TLS terminator in front of relay + group service.
#
# ACME lives here. MediaMTX has none, and a terminator behind this one would be a second
# certificate for one name.
#
# Routing table is the app repo's Caddyfile, parameterised by environment. Its upstream
# defaults are loopback, which is this host, so only the name is set. A table retyped in Nix
# would drift.

{
  config,
  lib,
  inputs,
  ...
}:

{
  options.screenshare.domain = lib.mkOption {
    type = lib.types.str;
    example = "streamrelay.example.com";
    description = ''
      Public name the relay answers on, and what its certificate is issued for.

      DNS must already resolve it to this host. Caddy asks Let's Encrypt on first start and
      answers the challenge on port 80.
    '';
  };

  config = {
    services.caddy = {
      enable = true;
      configFile = "${inputs.screen-sharing}/deploy/Caddyfile";
    };

    systemd.services.caddy.environment.SCREENSHARE_DOMAIN = config.screenshare.domain;

    networking.firewall = {
      # 80 carries ACME's challenge and the redirect to 443. Closing it stops renewal.
      allowedTCPPorts = [
        80
        443
      ];
      # HTTP/3.
      allowedUDPPorts = [ 443 ];
    };
  };
}

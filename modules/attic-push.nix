{ config, pkgs, ... }:

# Pull + push for the self-hosted Attic cache nix-cache.bjoernblessin.de/system.
# Server + storage live in hh-cluster-infra: atticd on k3s, NAR chunks in Garage
# S3.
#
# Read is public (anonymous), so pull needs only the URL + cache public key.
# Push needs a JWT token; watch-store uploads local build outputs as they land,
# mirroring the old cachix-watch-store. Upstream paths (cache.nixos.org) are
# filtered out by default, so only own builds go up.
#
# Change the token: sops secrets/attic.yaml
# Seed existing store once: attic push hh:system $(nix path-info --all)

let
  cacheUrl = "https://nix-cache.bjoernblessin.de/system";
  # From `attic cache info system`, set after the cache is created. name:base64.
  publicKey = "system:/IHGc/pVuNl/6E7upaCDAhflf9R3gMMPRmp6qS9JiR0=";
in
{
  nix.settings = {
    extra-substituters = [ cacheUrl ];
    extra-trusted-substituters = [ cacheUrl ];
    extra-trusted-public-keys = [ publicKey ];
  };

  environment.systemPackages = [ pkgs.attic-client ];

  sops.secrets.attic-token.sopsFile = ../secrets/attic.yaml;

  # attic reads $XDG_CONFIG_HOME/attic/config.toml and has no flag to point
  # elsewhere. sops renders the token-bearing config; the service copies it into
  # its runtime dir. A generated config in the Nix store would leak the token
  # world-readable.
  sops.templates."attic.toml" = {
    restartUnits = [ "attic-watch-store.service" ];
    content = ''
      default-server = "hh"

      [servers.hh]
      endpoint = "https://nix-cache.bjoernblessin.de/"
      token = "${config.sops.placeholder.attic-token}"
    '';
  };

  systemd.services.attic-watch-store = {
    description = "Push new store paths to the Attic binary cache";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "simple";
      RuntimeDirectory = "attic-watch-store";
      RuntimeDirectoryMode = "0700";
      # attic wants config at $XDG_CONFIG_HOME/attic/config.toml.
      Environment = "XDG_CONFIG_HOME=/run/attic-watch-store";
      ExecStartPre = "${pkgs.coreutils}/bin/install -Dm400 ${config.sops.templates."attic.toml".path} /run/attic-watch-store/attic/config.toml";
      ExecStart = "${pkgs.attic-client}/bin/attic watch-store hh:system";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}

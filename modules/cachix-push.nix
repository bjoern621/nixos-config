{ config, pkgs, ... }:

# Pushes build outputs to the bjoern621 Cachix cache and uses it as a
# substituter. cachix-watch-store uploads new store paths as they appear;
# upstream covers only the push side, hence nix.settings below.
#
# Everything entering the store is uploaded, including paths substituted from
# cache.nixos.org. The cache is public, so this exposes every build output.
#
# Change the token with: sops secrets/cachix.yaml
# Seed the pre-existing store once: nix path-info --all | cachix push bjoern621

let
  cacheName = "bjoern621";
  publicKey = "bjoern621.cachix.org-1:IbOBu2sdQu4XkDqafw3sdvOfbdMv/MGhoGwtHubRgmE=";
in
{
  nix.settings = {
    extra-substituters = [ "https://${cacheName}.cachix.org" ];
    extra-trusted-substituters = [ "https://${cacheName}.cachix.org" ];
    extra-trusted-public-keys = [ publicKey ];
  };

  # cachix CLI for the manual seed run above and for ad-hoc pushes.
  environment.systemPackages = [ pkgs.cachix ];

  sops.secrets.cachix-token = {
    sopsFile = ../secrets/cachix.yaml;
    restartUnits = [ "cachix-watch-store-agent.service" ];
  };

  services.cachix-watch-store = {
    enable = true;
    inherit cacheName;
    cachixTokenFile = config.sops.secrets.cachix-token.path;
  };
}

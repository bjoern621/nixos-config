{ pkgs, ... }:

# GeoIP database for the in-cluster otel-collector,
# which mounts /var/lib/geoip as a hostPath and locates Traefik clients
# (hh-cluster-infra, argocd/applications/observability).
# Copied, never symlinked: a link into /nix/store dangles inside the container.
# C+ replaces the copy on every activation, so a nixpkgs bump refreshes it.

let
  geoipDb = pkgs.callPackage ../pkgs/geoip-city-db.nix { };
in
{
  systemd.tmpfiles.rules = [
    "d /var/lib/geoip 0755 root root -"
    "C+ /var/lib/geoip/city.mmdb - - - - ${geoipDb}/share/geoip/city.mmdb"
  ];
}

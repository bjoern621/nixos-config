# Self-hosted group screen sharing: https://github.com/bjoern621/screen-sharing
#
# The flake's NixOS module carries the kmsgrab capability wrapper alone (hosts/nixos/flake.nix),
# so both binaries and the desktop entry come from the package here.
{ inputs, pkgs, ... }:

{
  home.packages = [
    inputs.screen-sharing.packages.${pkgs.stdenv.hostPlatform.system}.screen-sharing
  ];
}

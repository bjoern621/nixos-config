{ inputs, pkgs, ... }:

{
  home.packages = [
    inputs.screen-sharing.packages.${pkgs.stdenv.hostPlatform.system}.mirrorme
  ];
}

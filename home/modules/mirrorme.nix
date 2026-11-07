{ inputs, pkgs, ... }:

{
  home.packages = [
    inputs.mirrorme.packages.${pkgs.stdenv.hostPlatform.system}.mirrorme
  ];
}

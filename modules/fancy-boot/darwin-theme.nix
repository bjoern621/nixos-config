# Plymouth theme package for darwin-plymouth boot splash screen
# This Nix derivation packages the macOS-inspired Plymouth theme from:
# https://github.com/libredeb/darwin-plymouth
#
# The theme provides a sophisticated and minimalist boot animation
# that mimics the macOS boot experience. All theme assets are
# installed to /usr/share/plymouth/themes/darwin/
#
# Usage:
#   Add this package to boot.plymouth.themePackages and set
#   boot.plymouth.theme = "darwin"

{ stdenv, lib }:

stdenv.mkDerivation rec {
  pname = "darwin-plymouth";
  version = "2.0";

  src = ./darwin;

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/share/plymouth/themes/darwin
    cp -r * $out/share/plymouth/themes/darwin/
  '';

  meta = with lib; {
    description = "A sophisticated and minimalist Plymouth theme inspired by macOS";
    homepage = "https://github.com/libredeb/darwin-plymouth";
    license = licenses.unfree;
    maintainers = [];
  };
}

{
  inputs,
  config,
  pkgs,
  ...
}:

let
  hyprlandPkgs = inputs.hyprland.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  # Hyprland runs on glibc of its own nixpkgs pin and dlopens mesa from /run/opengl-driver.
  # Mesa from a newer pin needs newer glibc, GBM fails and the compositor aborts at login.
  # https://wiki.hypr.land/Nix/Hyprland-on-NixOS/
  hardware.graphics.package = hyprlandPkgs.mesa;

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;

    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage =
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;

    # https://wiki.hypr.land/Useful-Utilities/Systemd-start/#uwsm
    withUWSM = true;
  };

  # Hint electron apps to use wayland
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}

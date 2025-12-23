{ inputs, config, pkgs, ... }:

{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;

    # https://wiki.hypr.land/Nix/Hyprland-on-NixOS/
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  # Hint electron apps to use wayland
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}

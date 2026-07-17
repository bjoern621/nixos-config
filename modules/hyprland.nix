{
  inputs,
  config,
  pkgs,
  ...
}:

{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;

    # TEMPORARY: Using nixpkgs packages until Hyprland flake is fixed.
    # Revert to: inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland
    package = pkgs.hyprland;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;

    # https://wiki.hypr.land/Useful-Utilities/Systemd-start/#uwsm
    withUWSM = true;
  };

  # Hint electron apps to use wayland
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}

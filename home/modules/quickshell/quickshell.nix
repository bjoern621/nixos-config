{
  inputs,
  pkgs,
  config,
  ...
}:

{
  # User-level quickshell configuration.
  # NOTE: This module is paired with modules/quickshell.nix
  # which contains system-level dependencies like UPower.

  home.packages = with pkgs; [
    inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default
    # inputs.caelestia-shell.packages.${pkgs.stdenv.hostPlatform.system}.default
    font-awesome # Icons
    inter # Text
  ];

  # Link quickshell config to ~/.config/quickshell via an out-of-store symlink
  # so that Quickshell's hot reload can detect file changes directly in the repo.
  xdg.configFile."quickshell".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/git/nixos-config/home/modules/quickshell/config/dynamic-island";

  # Autostart quickshell
  wayland.windowManager.hyprland.settings.exec-once = [
    "quickshell"
    # "caelestia-shell"
  ];

  # Hyprland layerrule for quickshell blur effect
  wayland.windowManager.hyprland.settings.layerrule = [
    "blur on, match:namespace quickshell"
  ];

  fonts.fontconfig.enable = true;
}

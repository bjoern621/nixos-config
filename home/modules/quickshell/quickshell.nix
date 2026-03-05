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

  # Hyprland layerrule for quickshell blur effect.
  # ignore_alpha 0.1 skips blur on pixels with alpha <= 0.1, so the transparent
  # PanelWindow background is not blurred, only the pill (alpha 0.7) is.
  # When the pill is slid off-screen it is clipped, leaving only the transparent
  # background, so blur disappears without any extra logic.
  wayland.windowManager.hyprland.settings.layerrule = [
    "blur on, match:namespace quickshell"
    "ignore_alpha 0.1, match:namespace quickshell"
  ];

  fonts.fontconfig.enable = true;
}

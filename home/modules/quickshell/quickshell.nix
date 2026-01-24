{ inputs, pkgs, ... }:

{
  home.packages = [
    inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # Link quickshell config to ~/.config/quickshell
  xdg.configFile."quickshell" = {
    source = ./config;
    recursive = true;
    # Allow overwriting existing files (e.g., .qmlls.ini) during activation
    force = true;
  };

  # Autostart quickshell
  wayland.windowManager.hyprland.settings.exec-once = [
    "quickshell"
  ];
}

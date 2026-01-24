{ inputs, pkgs, ... }:

{
  home.packages = [
    inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # Link quickshell config to ~/.config/quickshell
  #   xdg.configFile."quickshell" = {
  #     source = ./config;
  #     recursive = true;
  #     # Allow overwriting existing files (e.g., .qmlls.ini) during activation
  #     force = true;
  #   };

  # Autostart quickshell
  wayland.windowManager.hyprland.settings.exec-once = [
    "quickshell"
  ];

  programs.caelestia = {
    enable = true;
    systemd = {
      enable = false; # if you prefer starting from your compositor
      target = "graphical-session.target";
      environment = [ ];
    };
    settings = {
      bar.status = {
        showBattery = true;
      };
      paths.wallpaperDir = "/etc/nixos/config/home/wallpapers";
    };
    cli = {
      enable = true; # Also add caelestia-cli to path
      settings = {
        theme.enableGtk = false;
      };
    };
  };
}

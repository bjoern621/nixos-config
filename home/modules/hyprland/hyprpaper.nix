{ config, pkgs, ... }:

let
  #   wallpaper = "${config.home.homeDirectory}/.local/share/wallpapers/Zelda.no.Densetsu.full.3709265.jpg";
  #   wallpaper = "/home/bjoern/.local/share/wallpapers/Zelda.no.Densetsu.full.3709265.jpg";
  #   wallpaper = ../../wallpapers/Zelda.no.Densetsu.full.3709265.jpg;
in
{
  #   # Copy the entire wallpapers directory.
  home.file.".local/share/wallpapers".source = ../../wallpapers;

  #   # https://nix-community.github.io/home-manager/options.xhtml#opt-services.hyprpaper.enable
  services.hyprpaper = {
    enable = true;
    settings = {
      preload = [ "/home/bjoern/.local/share/wallpapers/Ashes.jpg" ];
      wallpaper = [ ",/home/bjoern/.local/share/wallpapers/Ashes.jpg" ];
    };
  };

  #   # Ensure hyprpaper starts only after Hyprland has initialized its wayland
  #   # socket and registered monitor outputs. Without this, graphical-session.target
  #   # fires too early and hyprpaper finds no outputs, leaving a blank screen.
  #   systemd.user.services.hyprpaper.Unit.After = [
  #     "graphical-session.target"
  #     "wayland-wm@hyprland.desktop.service"
  #   ];

  # https://wiki.hypr.land/Configuring/Variables/#misc
  wayland.windowManager.hyprland.settings.misc = {
    disable_splash_rendering = true;
    disable_hyprland_logo = true;
  };
}

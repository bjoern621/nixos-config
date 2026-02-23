{ config, pkgs, ... }:

let
  wallpaper_rel_path = ".local/share/wallpapers";
in
{
  # Copy the entire wallpapers directory.
  home.file."${wallpaper_rel_path}".source = ../../wallpapers;

  # https://nix-community.github.io/home-manager/options.xhtml#opt-services.hyprpaper.enable
  services.hyprpaper = {
    enable = true;
    settings = {
      splash = false;

      wallpaper = [
        {
          monitor = "";
          path = "${config.home.homeDirectory}/${wallpaper_rel_path}/Honor.jpg";
        }
      ];
    };
  };

  # https://wiki.hypr.land/Configuring/Variables/#misc
  wayland.windowManager.hyprland.settings.misc = {
    disable_splash_rendering = true;
    disable_hyprland_logo = true;
  };
}

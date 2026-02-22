{ config, ... }:

let
  wallpaper = "${config.home.homeDirectory}/.local/share/wallpapers/Zelda.no.Densetsu.full.3709265.jpg";
in
{
  # Copy the entire wallpapers directory.
  home.file.".local/share/wallpapers".source = ../../wallpapers;

  # https://nix-community.github.io/home-manager/options.xhtml#opt-services.hyprpaper.enable
  services.hyprpaper = {
    enable = true;
    settings = {
      preload = [ wallpaper ];
      wallpaper = [ ",${wallpaper}" ];
    };
  };

  # https://wiki.hypr.land/Configuring/Variables/#misc
  wayland.windowManager.hyprland.settings.misc = {
    disable_splash_rendering = true;
    disable_hyprland_logo = true;
  };
}

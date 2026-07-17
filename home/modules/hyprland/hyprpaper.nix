{ ... }:

let
  wallpaper_rel_path = ".local/share/wallpapers";
in
{
  # Copy the entire wallpapers directory.
  home.file."${wallpaper_rel_path}".source = ../../wallpapers;

  # https://nix-community.github.io/home-manager/options.xhtml#opt-services.hyprpaper.enable
  # Wallpaper is applied at runtime by Quickshell's WallpaperBackend.
  services.hyprpaper = {
    enable = true;
    settings = {
      splash = false;
    };
  };

  wayland.windowManager.hyprland.extraLuaFiles."hyprpaper".content = ./hyprpaper.lua;
}

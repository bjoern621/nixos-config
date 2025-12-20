{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    hyprpaper
  ];

  # Create config file hyprpaper.conf
  # XDG = Cross-Desktop Group (https://www.freedesktop.org/wiki/)
  # specification that standardizes where apps should store files on Linux
  xdg.configFile."hypr/hyprpaper.conf".text = 
  ''
    preload = ../../wallpapers/Ashes.jpg
    wallpaper = ,../../wallpapers/Ashes.jpg
  '';
}

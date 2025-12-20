{ config, pkgs, ... }:

let
  # Nix path to wallpaper file, copied to /nix/store at build time.
  # Use ${wallpaper} to interpolate the absolute store path into configs.
  wallpaper = ../../wallpapers/Ashes.jpg;
in
{
  home.packages = with pkgs; [
    hyprpaper
  ];

  # Create config file hyprpaper.conf
  # XDG = Cross-Desktop Group (https://www.freedesktop.org/wiki/)
  # specification that standardizes where apps should store files on Linux
  xdg.configFile."hypr/hyprpaper.conf".text = ''
    preload = ${wallpaper}
    wallpaper = ,${wallpaper}
  '';
}

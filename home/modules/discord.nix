{ config, pkgs, ... }:

{
  # Discord (user-level installation)
  home.packages = with pkgs; [
    discord
  ];

  # Discord desktop entry with Wayland flags
  xdg.desktopEntries.discord = {
    name = "Discord";
    genericName = "Internet Messenger";
    exec = "discord --enable-features=UseOzonePlatform --ozone-platform=wayland %U";
    terminal = false;
    icon = "discord";
    categories = [ "Network" "InstantMessaging" ];
    mimeType = [ "x-scheme-handler/discord" ];
  };
}

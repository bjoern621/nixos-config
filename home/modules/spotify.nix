{ config, pkgs, ... }:

{
  # Spotify (user-level installation)
  home.packages = with pkgs; [
    spotify
  ];

  # Spotify desktop entry modifications (optional)
  xdg.desktopEntries.spotify = {
    name = "Spotify";
    genericName = "Music Player";
    exec = "spotify %U";
    terminal = false;
    icon = "spotify-client";
    categories = [ "Audio" "Music" "Player" "AudioVideo" ];
    mimeType = [ "x-scheme-handler/spotify" ];
  };
}

# wdisplays with launcher search keywords.
#
# Upstream entry carries no Keywords line: launcher finds it only by "Displays".
# Copy in $XDG_DATA_HOME/applications shadows package's entry of same desktop-file id.
# Launcher matches no umlauts: German keywords spell ä/ö/ü as ae/oe/ue.
{ pkgs, ... }:

let
  keywords = [
    "monitor"
    "bildschirm"
    "display"
    "anzeige"
    "screen"
    "settings"
    "einstellungen"
    "resolution"
    "aufloesung"
    "scale"
    "skalierung"
    "layout"
    "anordnung"
    "refresh"
    "bildwiederholrate"
    "beamer"
    "projector"
    "wdisplays"
  ];

  desktopEntryWithKeywords = pkgs.runCommand "wdisplays-desktop-keywords" { } ''
    sed '/^Categories=/a Keywords=${pkgs.lib.concatStringsSep ";" keywords};' \
      ${pkgs.wdisplays}/share/applications/network.cycles.wdisplays.desktop > $out
  '';
in
{
  home.packages = [ pkgs.wdisplays ];

  xdg.dataFile."applications/network.cycles.wdisplays.desktop".source = desktopEntryWithKeywords;
}

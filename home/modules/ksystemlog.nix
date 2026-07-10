# KSystemLog with launcher search keywords.
#
# The upstream desktop entry localizes Keywords: the German list has no
# "journal" or "logs", so launcher search in a de locale cannot find the app
# by those terms. A copy of the entry with both terms prepended is installed
# to $XDG_DATA_HOME/applications, which takes precedence over the package's
# copy in the profile for the same desktop-file id.
{ pkgs, ... }:

let
  desktopEntryWithKeywords = pkgs.runCommand "ksystemlog-desktop-keywords" { } ''
    sed -e 's/^Keywords=/Keywords=journal;logs;/' \
        -e 's/^Keywords\[de\]=/Keywords[de]=journal;logs;/' \
      ${pkgs.kdePackages.ksystemlog}/share/applications/org.kde.ksystemlog.desktop > $out
  '';
in
{
  home.packages = [ pkgs.kdePackages.ksystemlog ];

  xdg.dataFile."applications/org.kde.ksystemlog.desktop".source = desktopEntryWithKeywords;
}

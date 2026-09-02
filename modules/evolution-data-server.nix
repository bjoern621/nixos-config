{ ... }:

# Calendar/contact backend behind GNOME Calendar.
# System level: D-Bus activation files and user units reach the session
# through services.dbus.packages and systemd.packages.
# Account definitions live in home/modules/calendar.nix.

{
  services.gnome.evolution-data-server.enable = true;

  # GSettings writes need a dconf daemon.
  # Without one they land in the memory backend and vanish on exit.
  programs.dconf.enable = true;
}

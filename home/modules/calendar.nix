{
  config,
  lib,
  pkgs,
  ...
}:

# GNOME Calendar plus the Radicale account it reads.
# Backend registration is system level, modules/evolution-data-server.nix.

let
  # Filename base is the source UID. Keyring items key off it
  # (secret-service attribute e-source-uid).
  uid = "radicale";

  # Group names are evolution-data-server's E_SOURCE_EXTENSION_* strings,
  # keys are its GObject property names camel-cased.
  # ResourcePath is one calendar collection under /dav/<user>/<name>/.
  # A principal URL resolves to no calendar.
  source = pkgs.writeText "${uid}.source" ''
    [Data Source]
    DisplayName=Radicale
    Enabled=true

    [Calendar]
    BackendName=caldav
    Color=#3584e4
    Selected=true

    [Authentication]
    Host=calendar.bjoernblessin.de
    Method=plain/password
    Port=443
    ProxyUid=system-proxy
    RememberPassword=true
    User=bjoern

    [Security]
    Method=tls

    [Offline]
    StaySynchronized=true

    [Refresh]
    Enabled=true
    IntervalMinutes=10

    [WebDAV Backend]
    ResourcePath=/dav/bjoern/personal/
    CalendarAutoSchedule=false
    AvoidIfmatch=false
  '';
in
{
  home.packages = [ pkgs.gnome-calendar ];

  # Installed as a writable copy.
  # The registry rewrites the file on a colour or visibility change,
  # and a store path refuses that write.
  # Activation restores the declared values over any such edit.
  #
  # Password is prompted once and kept in the keyring. Seed it instead with:
  #   secret-tool store --label=Radicale e-source-uid radicale \
  #     eds-origin evolution-data-server
  home.activation.calendarSources = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run install -Dm600 ${source} ${config.home.homeDirectory}/.config/evolution/sources/${uid}.source
  '';
}

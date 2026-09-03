{
  config,
  lib,
  pkgs,
  ...
}:

# GNOME Calendar plus the Radicale account it reads.
# Backend registration is system level, modules/evolution-data-server.nix.

let
  # Attr name is the source UID, and the filename base.
  # Keyring items key off it (secret-service attribute e-source-uid).
  #
  # Group names are evolution-data-server's E_SOURCE_EXTENSION_* strings,
  # keys are its GObject property names camel-cased.
  sources = {
    # Collection source: evolution-data-server walks CalendarUrl and writes one
    # child source per collection it finds, into ~/.cache/evolution/sources/radicale/.
    # Server owns which calendars exist and what each is called,
    # so a calendar added in the Radicale web interface appears here on its own.
    # DisplayName names the account.
    #
    # Discovery runs when the registry starts a backend for this source.
    # A start with no reachable server or a locked keyring yields no children,
    # and the next registry restart retries.
    radicale = ''
      [Data Source]
      DisplayName=Radicale
      Enabled=true

      [Collection]
      BackendName=webdav
      CalendarEnabled=true
      ContactsEnabled=false
      Identity=bjoern
      CalendarUrl=https://calendar.bjoernblessin.de/dav/bjoern/

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
    '';

    # Built-ins the registry seeds on first run, neither of which syncs anywhere.
    # Consumers read the enabled list whole rather than filtering it,
    # so switching them off here is what keeps them out of every client.
    # Enabled=false stops the backend; Selected=false only unticks a client sidebar.
    birthdays = ''
      [Data Source]
      DisplayName=Birthdays & Anniversaries
      Enabled=false
      Parent=contacts-stub

      [Calendar]
      BackendName=contacts
      Selected=false
    '';

    system-calendar = ''
      [Data Source]
      DisplayName=Personal
      Enabled=false
      Parent=local-stub

      [Calendar]
      BackendName=local
      Selected=false
    '';
  };

  sourceFiles = lib.mapAttrs (uid: text: pkgs.writeText "${uid}.source" text) sources;
in
{
  home.packages = [ pkgs.gnome-calendar ];

  # Installed as writable copies.
  # The registry rewrites a file on a colour or visibility change,
  # and a store symlink refuses that write.
  # Activation restores the declared values over any such edit.
  #
  # Radicale's password is prompted once and kept in the keyring. Seed it instead with:
  #   secret-tool store --label=Radicale e-source-uid radicale \
  #     eds-origin evolution-data-server
  home.activation.calendarSources = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        uid: file:
        "run install -Dm600 ${file} ${config.home.homeDirectory}/.config/evolution/sources/${uid}.source"
      ) sourceFiles
    )
  );
}

{ ... }:

{
  # Allow loopback when callers request it explicitly,
  # modules/keyring.nix provides pinentry-gnome3.
  home.file.".gnupg/gpg-agent.conf".text = ''
    allow-loopback-pinentry
  '';

  xdg.desktopEntries."org.gnome.seahorse.Application" = {
    name = "Schlüsselbund";
    genericName = "Passwörter und Schlüssel";
    comment = "Geheimnisse, Passwörter, Zertifikate und SSH-Schlüssel";
    settings.Keywords = "keyring;schluesselbund;passwort;passwoerter;credentials;secrets;ssh;zertifikate;";
    exec = "seahorse";
    icon = "org.gnome.seahorse.Application";
    terminal = false;
    startupNotify = true;
    type = "Application";
    categories = [
      "GNOME"
      "GTK"
      "Security"
      "Utility"
    ];
  };
}

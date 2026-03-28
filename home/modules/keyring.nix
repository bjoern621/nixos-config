{ ... }:

{
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

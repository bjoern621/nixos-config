{ config, pkgs, ... }:

{
  # See also: https://search.nixos.org/options?channel=25.11&query=keyring

  # Enable system secrets manager.
  # Allows apps to store credentials (like VSCode Settings Sync Account) securely.
  # Uses GNOME Keyring (other alternatives are Kwallet).
  services.gnome.gnome-keyring.enable = true; 

  # Enable GUI for showing stored secrets.
  programs.seahorse.enable = true;

  # pam_gnome_keyring will attempt to automatically unlock the user’s default Gnome keyring upon login.
  # Using services.>gdm<.enableGnomeKeyring because GDM is the current display manager.
  security.pam.services.gdm.enableGnomeKeyring = true;
}

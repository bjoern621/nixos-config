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
  # Applied to the login PAM service which SDDM substacks for session management.
  security.pam.services.login.enableGnomeKeyring = true;
}

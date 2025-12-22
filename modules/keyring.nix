{ config, pkgs, ... }:

{
  # See also: https://search.nixos.org/options?channel=25.11&query=keyring

  # Enable system secrets manager.
  # Allows apps to store credentials (like VSCode Settings Sync Account) securely.
  # Uses GNOME Keyring (other alternatives are Kwallet).
  services.gnome.gnome-keyring.enable = true; 

  # Enable GUI for showing stored secrets.
  programs.seahorse.enable = true; 
}

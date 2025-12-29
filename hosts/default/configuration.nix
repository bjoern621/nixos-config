# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hyprland.nix
    ../../modules/google-chrome.nix
    ../../modules/pipewire.nix
    ../../modules/scripts.nix
    ../../modules/quiet-boot.nix
    ../../modules/keyring.nix
    ../../modules/rmv-nixosmanual.nix
    ../../modules/rmv-xterm.nix
    ../../modules/login-screen.nix
    ../../modules/task-manager.nix
    ../../modules/power-management.nix
    ../../modules/screenshot.nix
    ../../modules/fancy-boot.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Latest Linux kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
  i18n.defaultLocale = "de_DE.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  # Configure console keymap
  console.keyMap = "de";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.bjoern = {
    isNormalUser = true;
    description = "Björn";
    extraGroups = [ 
      "networkmanager"
      "wheel" # Root access
    ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

  # Enable Spotify Connect discovery
  networking.firewall.allowedUDPPorts = [ 5353 ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ]; # Enable Flakes

  # Polkit (https://wiki.nixos.org/wiki/Polkit)
  security.polkit.enable = true;

  # TODO TB5/USB Tests
  # https://nixos.wiki/wiki/Thunderbolt
  environment.systemPackages = with pkgs; [
    kdePackages.plasma-thunderbolt
    wdisplays
    wlr-randr
    usbutils
  ];
  services.hardware.bolt.enable = true;
}

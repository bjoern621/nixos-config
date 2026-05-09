{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hyprland.nix
    ../../modules/google-chrome.nix
    ../../modules/pipewire.nix
    ../../modules/scripts/default.nix
    ../../modules/keyring.nix
    ../../modules/rmv-nixosmanual.nix
    ../../modules/rmv-xterm.nix
    ../../modules/task-manager.nix
    ../../modules/power-management.nix
    ../../modules/fancy-boot/fancy-boot.nix
    ../../modules/file-manager.nix
    ../../modules/printing.nix
    ../../modules/cleanup.nix
    # ../../modules/autologin.nix
    ../../modules/nix-search-tv.nix
    ../../modules/display-manager.nix
    ../../modules/wireguard.nix
    ../../modules/eduvpn-escape.nix
    ../../modules/networkmanager-openvpn.nix
    ../../modules/quickshell.nix
    ../../modules/hibernate.nix
    ../../modules/nix-ld.nix
    ../../modules/auto-update.nix
    ../../modules/howdy.nix
    ../../modules/fonts.nix
    ../../modules/tailscale-client.nix
    ../../modules/miracast.nix
    ../../modules/external-monitors.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Latest Linux kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # boot.kernelPackages = pkgs.linuxKernel.packages.linux_6_6;

  boot.kernelModules = [
    "thunderbolt"
    "nvme"
    "xhci_pci"
    "xhci_hcd"
    "usb_storage"
    "sd_mod"
  ];

  networking.hostName = "nixos"; # Define your hostname.
  networking.extraHosts = ''
    # HAW ITS 26s
    # Innerhalb des HAW-Netzes / per HAW-VPN erreichbar
    141.22.167.200 vm101.kss.ful.inf.haw-hamburg.de
    141.22.167.200 vm102.kss.ful.inf.haw-hamburg.de
    141.22.167.200 vm103.kss.ful.inf.haw-hamburg.de
    141.22.167.200 vm104.kss.ful.inf.haw-hamburg.de
    141.22.167.200 vm105.kss.ful.inf.haw-hamburg.de
    141.22.167.200 vm106.kss.ful.inf.haw-hamburg.de
    141.22.167.200 vm107.kss.ful.inf.haw-hamburg.de
    141.22.167.200 vm108.kss.ful.inf.haw-hamburg.de
    141.22.167.200 vm109.kss.ful.inf.haw-hamburg.de
    141.22.167.200 vm110.kss.ful.inf.haw-hamburg.de
    141.22.167.200 vm111.kss.ful.inf.haw-hamburg.de
    141.22.167.200 vm112.kss.ful.inf.haw-hamburg.de
    141.22.167.200 vm113.kss.ful.inf.haw-hamburg.de
    141.22.167.200 vm114.kss.ful.inf.haw-hamburg.de
    141.22.167.200 vm115.kss.ful.inf.haw-hamburg.de
    141.22.167.200 vm116.kss.ful.inf.haw-hamburg.de
    141.22.167.200 vm117.kss.ful.inf.haw-hamburg.de
    141.22.167.200 vm118.kss.ful.inf.haw-hamburg.de
    141.22.167.200 vm119.kss.ful.inf.haw-hamburg.de
    141.22.167.200 vm120.kss.ful.inf.haw-hamburg.de
    141.22.167.200 vm121.kss.ful.inf.haw-hamburg.de
    141.22.167.200 vm122.kss.ful.inf.haw-hamburg.de
  '';
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

  # Define a user account. Don’t forget to set a password with ‘passwd’.
  users.users.bjoern = {
    isNormalUser = true;
    description = "Björn";
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "wheel" # Root access via sudo
      "docker" # Docker access, effectively equivalent to being root (https://github.com/moby/moby/issues/9976)
    ];
  };

  programs.zsh.enable = true;

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

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ]; # Enable Flakes

  environment.systemPackages = with pkgs; [
    kdePackages.plasma-thunderbolt
    wdisplays
    wlr-randr
    usbutils
    brightnessctl
    tldr
  ];
  services.fwupd.enable = true;

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  virtualisation.docker.enable = true;

  system.hibernate = {
    enable = true;
    swapFile = {
      path = "/swapfile";
      resumeDevice = "/dev/disk/by-uuid/2b9e5bc2-459d-41ab-80af-6197bdadf407";
      size = 32;
      resumeOffset = 100587520;
    };
  };

  # Automatic weekly updates using 7-day delayed stable strategy
  # Updates all flake inputs to revisions that have "baked" for at least a week
  services.nixos-auto-update = {
    enable = true;
    user = "bjoern";
    delayDays = 7;
    schedule = "Mon 03:00";
  };
}

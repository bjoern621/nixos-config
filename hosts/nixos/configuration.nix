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
    ../../modules/scanning.nix
    ../../modules/cleanup.nix
    # ../../modules/autologin.nix
    ../../modules/nix-search-tv.nix
    ../../modules/display-manager.nix
    ../../modules/wireguard.nix
    ../../modules/eduvpn-escape.nix
    ../../modules/systemd-resolved.nix
    ../../modules/networkmanager-openvpn.nix
    ../../modules/quickshell.nix
    ../../modules/quickshell-lock.nix
    ../../modules/hibernate.nix
    ../../modules/nix-ld.nix
    ../../modules/sysconf-sudo.nix
    ../../modules/sysconf-auto-pull.nix
    ../../modules/howdy.nix
    ../../modules/fido2-auth.nix
    ../../modules/fonts.nix
    ../../modules/tailscale-client.nix
    ../../modules/garage-mount.nix
    # ../../modules/miracast.nix
    # ../../modules/sunshine.nix
    ../../modules/external-monitors.nix
    ../../modules/secureboot.nix
    ../../modules/tpm-luks.nix
    ../../modules/system-packages.nix
    ../../modules/sops.nix
    ../../modules/attic-push.nix
  ];

  services.tailscale-client.operator = "bjoern";

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

  # bitwarden-desktop still bundles electron 39, which nixpkgs now marks EOL.
  # Remove once bitwarden-desktop upstream moves to a maintained electron.
  nixpkgs.config.permittedInsecurePackages = [
    "electron-39.8.10"
  ];

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

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  services.fwupd.enable = true;

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  virtualisation.docker.enable = true;

  system.hibernate = {
    enable = true;
    swapFile = {
      path = "/swapfile";
      resumeDevice = "/dev/disk/by-uuid/fbfab8ba-1f6b-4b70-af59-0c37d8aea15a";
      size = 32;
      resumeOffset = 215146496;
    };
  };

  # Updates enter via CI stable flake.lock PRs (update-flake-locks.yml).
  # Host only converges to origin/main; never computes own revisions.
  services.sysconf-sudo.users = [ "bjoern" ];
  services.sysconf-auto-pull = {
    enable = true;
    user = "bjoern";
    schedule = "Mon 03:00";
  };
}

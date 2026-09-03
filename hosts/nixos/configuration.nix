{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hyprland.nix
    ../../modules/google-chrome.nix
    ../../modules/pipewire.nix
    ../../modules/scripts/default.nix
    ../../modules/keyring.nix
    ../../modules/evolution-data-server.nix
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
    ../../modules/dns.nix
    ../../modules/networkmanager-openvpn.nix
    ../../modules/proxy-domains-only-via-vpn.nix
    ../../modules/vpn-ipv6-leak-block.nix
    ../../modules/quickshell.nix
    ../../modules/quickshell-lock.nix
    ../../modules/hibernate.nix
    ../../modules/nix-ld.nix
    ../../modules/sysconf-sudo.nix
    ../../modules/sysconf-auto-pull.nix
    ../../modules/sysconf-revision.nix
    ../../modules/howdy.nix
    ../../modules/fido2-auth.nix
    ../../modules/fonts.nix
    ../../modules/tailscale-client.nix
    ../../modules/wireguard-wstunnel.nix
    ../../modules/miracast.nix
    # ../../modules/sunshine.nix
    ../../modules/external-monitors.nix
    ../../modules/secureboot.nix
    ../../modules/tpm-luks.nix
    ../../modules/usbguard.nix
    ../../modules/system-packages.nix
    ../../modules/tas2781-calibration/default.nix
    ../../modules/sops.nix
    ../../modules/attic-push.nix
    ../../modules/attic-pull-screen-sharing.nix
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
    # 141.22.167.200 vm101.kss.ful.inf.haw-hamburg.de
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

  sysconf.user = "bjoern";

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

  # bitwarden-desktop still bundles an EOL electron that nixpkgs marks insecure.
  # Bump the pin whenever the bundled electron moves; remove once upstream
  # bitwarden-desktop tracks a maintained electron.
  nixpkgs.config.permittedInsecurePackages = [
    "electron-40.10.5"
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
  services.sysconf-revision.enable = true;
}

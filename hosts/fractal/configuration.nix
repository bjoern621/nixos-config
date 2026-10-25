{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hyprland.nix
    ../../modules/nvidia.nix
    ../../modules/gaming.nix
    ../../modules/sleep-off.nix
    ../../modules/reboot-to-windows.nix
    ../../modules/google-chrome.nix
    ../../modules/pipewire.nix
    ../../modules/scripts/default.nix
    ../../modules/keyring.nix
    ../../modules/evolution-data-server.nix
    ../../modules/rmv-nixosmanual.nix
    ../../modules/rmv-xterm.nix
    ../../modules/task-manager.nix
    ../../modules/fancy-boot/fancy-boot.nix
    ../../modules/file-manager.nix
    ../../modules/printing.nix
    ../../modules/scanning.nix
    ../../modules/cleanup.nix
    ../../modules/nix-search-tv.nix
    ../../modules/display-manager.nix
    ../../modules/dns.nix
    ../../modules/networkmanager-openvpn.nix
    ../../modules/proxy-domains-only-via-vpn.nix
    ../../modules/vpn-ipv6-leak-block.nix
    ../../modules/quickshell.nix
    ../../modules/kernel-crash-reboot.nix
    ../../modules/nix-ld.nix
    ../../modules/sysconf-sudo.nix
    ../../modules/sysconf-auto-pull.nix
    ../../modules/sysconf-revision.nix
    ../../modules/fido2-auth.nix
    ../../modules/fonts.nix
    ../../modules/tailscale-client.nix
    ../../modules/secureboot.nix
    ../../modules/tpm-luks.nix
    ../../modules/system-packages.nix
    ../../modules/sops.nix
    ../../modules/nix-substituter-fallback.nix
    ../../modules/attic-pull-system.nix
    ../../modules/attic-push.nix
    ../../modules/attic-pull-screen-sharing.nix
    ../../modules/screen-sharing.nix
    ../../modules/mt7927-bluetooth.nix
  ];

  networking.hostName = "fractal";

  services.tailscale-client.operator = "bjoern";

  boot.loader.efi.canTouchEfiVariables = true;

  # Root LUKS mapper name, read off hardware-configuration.nix (docs/installation.md).
  boot.initrd.luks.tpm2Unlock.devices = [ "cryptroot" ];

  # LUKS volume on second disk, created by hand (docs/installation.md)
  # with partlabel `games`. The key file lives on the encrypted root,
  # so the volume opens after root with no prompt.
  environment.etc.crypttab.text = ''
    games /dev/disk/by-partlabel/games /etc/luks/games.key luks,discard,nofail
  '';
  fileSystems."/games" = {
    device = "/dev/mapper/games";
    fsType = "ext4";
    options = [
      "nofail"
      "x-systemd.device-timeout=10s"
    ];
  };

  # Windows and the GPU option ROM carry Microsoft signatures;
  # a db without the Microsoft CA leaves the card dark before the kernel loads.
  boot.lanzaboote.autoEnrollKeys.includeMicrosoftKeys = true;

  # Nobody but the owner reaches the desk, so the greeter goes straight into the session.
  services.displayManager.autoLogin = {
    enable = true;
    user = "bjoern";
  };
  services.displayManager.defaultSession = "hyprland-uwsm";

  # display-manager.nix interpolates the howdy package into the greeter PAM stack
  # whether or not the service runs; the stub keeps the IR-camera stack out of the closure.
  services.howdy.package = pkgs.emptyDirectory;

  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Berlin";

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

  console.keyMap = "de";

  sysconf.user = "bjoern";

  users.users.bjoern = {
    isNormalUser = true;
    description = "Björn";
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker" # Docker access, effectively equivalent to being root (https://github.com/moby/moby/issues/9976)
    ];
  };

  programs.zsh.enable = true;

  nixpkgs.config.allowUnfree = true;

  # bitwarden-desktop still bundles an EOL electron that nixpkgs marks insecure.
  # Bump the pin whenever the bundled electron moves; remove once upstream
  # bitwarden-desktop tracks a maintained electron.
  nixpkgs.config.permittedInsecurePackages = [
    "electron-40.10.5"
  ];

  # Spotify Connect discovery
  networking.firewall.allowedUDPPorts = [ 5353 ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # 32 GB of RAM and no hibernation, so swap stays in memory.
  zramSwap.enable = true;

  services.fwupd.enable = true;

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  virtualisation.docker.enable = true;

  # Updates enter via CI stable flake.lock PRs (update-flake-locks.yml).
  # Host only converges to origin/main; never computes own revisions.
  services.sysconf-sudo.users = [ "bjoern" ];
  services.sysconf-auto-pull = {
    enable = true;
    user = "bjoern";
    schedule = "Mon 03:00";
  };
  services.sysconf-revision.enable = true;

  system.stateVersion = "26.11";
}

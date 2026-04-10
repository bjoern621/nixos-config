{
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/scripts/default.nix
    ../../modules/homelab/vm/hypervisor
    ../../modules/homelab/vm/k3s
    ../../modules/homelab/samba.nix
    ../../modules/homelab/storage.nix
    ../../modules/homelab/monitoring.nix
    ../../modules/homelab/ssh-hardening.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "homelab";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "de_DE.UTF-8";
  console.keyMap = "de";

  users.users.ops = {
    isNormalUser = true;
    description = "Operations";
    shell = pkgs.zsh;
    initialPassword = "1234";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILZtmzMiCFldBIJpMZAlaTgKOHrZypm7J8YHGnsSzhPC bjoern@nixos"
    ];
    extraGroups = [
      "wheel"
      "networkmanager"
      "docker"
      "libvirtd"
      "smbshare"
    ];
  };

  programs.zsh.enable = true;

  virtualisation.docker.enable = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.11";
}

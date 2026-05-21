{
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/scripts/default.nix
    ../../modules/auto-update.nix
    ../../modules/homelab/vm/hypervisor
    ../../modules/homelab/samba.nix
    ../../modules/homelab/mounts.nix
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
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKjTT3sunIot4AmUwDX3NbdS44g+oz9/enIXuxH2knmq laptop"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINoKgh7gTGHoM9dXQK/2VMJAf/IaExYsCX1/trFrw1qS pc"
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

  services.nixos-auto-update = {
    enable = true;
    user = "ops";
    delayDays = 7;
    schedule = "Mon 03:00";
  };
}

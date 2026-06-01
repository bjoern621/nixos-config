{
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/scripts/default.nix
    ../../modules/sysconf-sudo.nix
    ../../modules/sysconf-auto-pull.nix
    ../../modules/admin-ssh-keys.nix
    ../../modules/homelab/vm/hypervisor
    ../../modules/homelab/samba.nix
    ../../modules/homelab/mounts.nix
    ../../modules/homelab/storage.nix
    ../../modules/homelab/monitoring.nix
    ../../modules/homelab/ssh-hardening.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "homelab";
  # Host networking (br0 bridge via systemd-networkd) lives in the hypervisor
  # module, which the VMs' network ports connect to. NetworkManager is
  # intentionally not used on this host.

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "de_DE.UTF-8";
  console.keyMap = "de";

  services.admin-ssh-keys.users = [ "ops" ];
  services.sysconf-sudo.users = [ "ops" ];
  services.sysconf-auto-pull = {
    enable = true;
    user = "ops";
    schedule = "daily";
  };

  users.users.ops = {
    isNormalUser = true;
    description = "Operations";
    shell = pkgs.zsh;
    initialPassword = "1234";
    extraGroups = [
      "wheel"
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

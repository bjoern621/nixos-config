{ pkgs, modulesPath, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/scripts/default.nix
    ../../modules/auto-update.nix
    ../../modules/admin-ssh-keys.nix
    ../../modules/backup-source.nix
    ../../modules/vmk3s/bitwarden-dump.nix
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "vmk3s";

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "de_DE.UTF-8";
  console.keyMap = "de";

  services.admin-ssh-keys.users = [ "ops" ];

  users.users.ops = {
    isNormalUser = true;
    description = "Operations";
    shell = pkgs.zsh;
    initialPassword = "1234";
    extraGroups = [
      "wheel"
    ];
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.11";

  # Additional configuration:

  programs.zsh.enable = true;

  services.openssh.enable = true;

  # Kubernetes API server for remote kubectl and GitOps controllers.
  # Argo CD UI is exposed as NodePort on 32443.
  networking.firewall.allowedTCPPorts = [
    6443
    32443
    31478
    31553
  ];

  services.k3s = {
    enable = true;
    role = "server";
  };

  environment.systemPackages = with pkgs; [
    k3s
    kubectl
    tldr
  ];

  services.nixos-auto-update = {
    enable = true;
    user = "ops";
    delayDays = 7;
    schedule = "Mon 03:00";
  };

  # Daily disaster-recovery dump of Bitwarden into /var/backups/bitwarden,
  # picked up by the pi-backup hosts over rsync.
  services.bitwarden-dump.enable = true;

  # Read-only rrsync access to the dump directory for each Pi.
  services.backup-source = {
    enable = true;
    allowedPath = "/var/backups/bitwarden";
    authorizedKeys = [
      # Paste the public half of the keypair distributed to each Pi.
      # The matching private key lives on the Pi at
      # /home/ops/.ssh/backup_pull_id_ed25519 (ops:ops, mode 0400).
      # One entry per Pi (or one shared entry for all Pis); pi-backup-NN names
      # are just human-readable comments used to revoke individual hosts.
      {
        name = "pi-backup-01";
        key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINzPEPmeh9uuXE1Uo+/MfzPJfvkaMyMyRrdz4IgOLEtF pi-backup-01";
      }
    ];
  };
}

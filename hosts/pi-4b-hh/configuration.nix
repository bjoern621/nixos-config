{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/scripts/default.nix
    ../../modules/auto-update.nix
    ../../modules/admin-ssh-keys.nix
    ../../modules/homelab/ssh-hardening.nix
    ../../modules/tailscale-client.nix
    ../../modules/smokeping.nix
    ../../modules/pi-backup
  ];

  services.admin-ssh-keys.users = [ "ops" ];

  # Raspberry Pi 4 boots via U-Boot extlinux, not GRUB or systemd-boot.
  boot.loader.grub.enable = false;
  boot.loader.systemd-boot.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "pi-4b-hh";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "de_DE.UTF-8";
  console.keyMap = "de";

  users.users.ops = {
    isNormalUser = true;
    description = "Operations";
    shell = pkgs.zsh;
    initialPassword = "1234";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  programs.zsh.enable = true;

  # On first boot the SD card image has no /etc/nixos/config git clone and no
  # /etc/nixos/hardware-configuration.nix because the image bypasses nixos-install.
  # This service clones the repository and creates a symlink for the hardware
  # config so that sysconf-pull and sysconf-reload work without any manual steps.
  systemd.services.nixos-config-setup = {
    description = "Clone NixOS config repository on first boot";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "!/etc/nixos/config/.git";
    path = [ pkgs.git ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail
      git clone https://github.com/bjoern621/nixos-config.git /etc/nixos/config
      chown -R ops:users /etc/nixos/config
      cp /etc/nixos/config/hosts/pi-4b-hh/hardware-configuration.nix /etc/nixos/hardware-configuration.nix
    '';
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.11";

  # Backup target side. See hosts/vmk3s/configuration.nix for the source side.
  #
  # Daily at 03:30 UTC the Pi pulls from vmk3s into
  # /srv/backups/snapshots/<job>/<UTC-stamp>/. Each job uses --link-dest
  # against the previous run for hardlink dedup, then prunes to 30 daily
  # plus 12 weekly snapshots.
  #
  # What is backed up:
  #   bitwarden-pg    pg_dump of the bitwarden vault DB
  #                   (vmk3s:/var/backups/bitwarden/postgres.dump)
  #   bitwarden-pvc   bitwarden namespace PVCs (attachments)
  #   webdav-pvc      webdav namespace PVCs (Obsidian + GoodNotes vaults)
  #
  # Restore:
  #   Bitwarden DB    pg_restore /srv/backups/snapshots/bitwarden-pg/latest/postgres.dump
  #                   into a fresh bitwarden postgres pod.
  #   Bitwarden PVCs  copy /srv/backups/snapshots/bitwarden-pvc/latest/pvc-*/
  #                   back under /var/lib/rancher/k3s/storage/ on a fresh node.
  #   WebDAV PVCs     same pattern, from snapshots/webdav-pvc/latest/.
  #
  # Adding a service: add a job below pointing at `k3s-pvcs/` and
  # filtering to the service's namespace. If the service has a database,
  # add a logical-dump module on the source side too.
  #
  # SSH key: the matching private half of the source host's authorizedKeys
  # entry lives at /home/ops/.ssh/backup_pull_id_ed25519 (ops:ops, 0400),
  # deployed out-of-band.

  # External USB drive, LUKS-encrypted, mounted at /srv/backups. To provision:
  #   1. Plug in the drive, identify with `lsblk`.
  #   2. Create one partition.
  #   3. `cryptsetup luksFormat /dev/<part>` (strong passphrase, recorded offline).
  #   4. `blkid /dev/<part>` -> copy UUID into `deviceUuid` below.
  #   5. `cryptsetup luksOpen /dev/<part> backup`
  #      `mkfs.ext4 /dev/mapper/backup`
  #      `cryptsetup luksClose backup`
  #   6. Flip `enable = true` and run `sysconf-reload`.
  services.pi-backup.storage = {
    enable = false;
    deviceUuid = "00000000-0000-0000-0000-000000000000";
  };

  services.pi-backup.jobs = {
    bitwarden-pg = {
      host = "vmk3s";
      remoteUser = "root";
      remotePath = "bitwarden/";
      schedule = "*-*-* 03:30:00";
      keepDaily = 30;
      keepWeekly = 12;
    };

    bitwarden-pvc = {
      host = "vmk3s";
      remoteUser = "root";
      remotePath = "k3s-pvcs/";
      extraRsyncArgs = [
        "--include=pvc-*_bitwarden_*/"
        "--include=pvc-*_bitwarden_*/***"
        "--exclude=*"
      ];
      schedule = "*-*-* 03:30:00";
      keepDaily = 30;
      keepWeekly = 12;
    };

    webdav-pvc = {
      host = "vmk3s";
      remoteUser = "root";
      remotePath = "k3s-pvcs/";
      extraRsyncArgs = [
        "--include=pvc-*_webdav_*/"
        "--include=pvc-*_webdav_*/***"
        "--exclude=*"
      ];
      schedule = "*-*-* 03:30:00";
      keepDaily = 30;
      keepWeekly = 12;
    };
  };

  services.nixos-auto-update = {
    enable = true;
    user = "ops";
    delayDays = 7;
    schedule = "Mon 03:00";
  };
}

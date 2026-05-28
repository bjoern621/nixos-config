{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/scripts/default.nix
    ../../modules/auto-update.nix
    ../../modules/admin-ssh-keys.nix
    ../../modules/homelab/ssh-hardening.nix
    ../../modules/tailscale-client.nix
    ../../modules/pi-backup
  ];

  services.admin-ssh-keys.users = [ "ops" ];

  # Raspberry Pi 4 boots via U-Boot extlinux, not GRUB or systemd-boot.
  boot.loader.grub.enable = false;
  boot.loader.systemd-boot.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  # nixos-hardware's raspberry-pi-4 module pins firmware and overlays; do not
  # override boot.kernelPackages here without a specific reason.

  networking.hostName = "pi-backup-01";
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

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.11";

  # The backup volume lives on an external USB SSD/HDD encrypted with LUKS.
  # Steps to provision before flipping `enable = true`:
  #   1. Plug the drive in. Identify it: `lsblk`.
  #   2. Create a single partition.
  #   3. `cryptsetup luksFormat /dev/<partition>` (set a strong passphrase; record it offline).
  #   4. `blkid /dev/<partition>` -> copy the UUID into `deviceUuid` below.
  #   5. `cryptsetup luksOpen /dev/<partition> backup`
  #      `mkfs.ext4 /dev/mapper/backup`
  #      `cryptsetup luksClose backup`
  #   6. Flip `enable = true` and run `sysconf-reload`.
  services.pi-backup.storage = {
    enable = false;
    deviceUuid = "00000000-0000-0000-0000-000000000000";
  };

  # Private SSH key for the pull is not generated here; copy it onto the Pi
  # out-of-band at /home/ops/.ssh/backup_pull_id_ed25519 (ops:ops, mode 0400).
  # The matching public key must already be in the authorizedKeys list on the
  # source host (see hosts/vmk3s/configuration.nix).

  # One job per source. The remoteUser is restricted to a single read-only
  # rrsync command on the source side, so remotePath is relative to that root.
  # All jobs share one SSH key (default sshKey path). vmk3s exposes both
  # source trees as read-only bind mounts under one rrsync chroot, so a
  # single forced-command on root authorizes both pulls.
  services.pi-backup.jobs = {
    bitwarden = {
      host = "vmk3s";
      remoteUser = "root";
      remotePath = "bitwarden/";
      schedule = "*-*-* 03:30:00";
      keepDaily = 30;
      keepWeekly = 12;
    };

    # Direct rsync of the webdav PVC tree. The `webdav-pvc` mount on
    # vmk3s exposes the whole k3s local-path storage tree, so the
    # include/exclude filter limits the pull to the webdav namespace's
    # PVC dir(s). --link-dest dedup keeps the on-disk cost ~constant
    # across daily snapshots.
    webdav = {
      host = "vmk3s";
      remoteUser = "root";
      remotePath = "webdav-pvc/";
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

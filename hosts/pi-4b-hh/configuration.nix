{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/scripts/default.nix
    ../../modules/sysconf-checkout.nix
    ../../modules/sysconf-sudo.nix
    ../../modules/sysconf-auto-pull.nix
    ../../modules/sysconf-revision.nix
    ../../modules/admin-ssh-keys.nix
    ../../modules/homelab/ssh-hardening.nix
    ../../modules/tailscale-client.nix
    ../../modules/smokeping.nix
    ../../modules/pi-backup
    ../../modules/telemetry-agent.nix
    ../../modules/victoria-stack
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

  sysconf.user = "ops";
  sysconf.checkout.enable = true;

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

  # Local observability stack per the architecture diagram: full store set
  # (VM, VL, VT, 14d) + Grafana. Ingests replicas from vmk3s and homelab
  # over the tailnet; own collector pushes the same fan-out back.
  services.victoria-stack.enable = true;

  services.telemetry-agent = {
    enable = true;
    stacks = {
      local = {
        metricsUrl = "http://127.0.0.1:8428/api/v1/write";
        logsUrl = "http://127.0.0.1:9428/insert/opentelemetry/v1/logs";
        tracesUrl = "http://127.0.0.1:10428/insert/opentelemetry/v1/traces";
      };
      vmk3s = {
        metricsUrl = "http://victoria-metrics-vmk3s.tail115f30.ts.net:8428/api/v1/write";
        logsUrl = "http://victoria-logs-vmk3s.tail115f30.ts.net:9428/insert/opentelemetry/v1/logs";
        tracesUrl = "http://victoria-traces-vmk3s.tail115f30.ts.net:10428/insert/opentelemetry/v1/traces";
      };
    };
    scrapeConfigs = [
      {
        job_name = "smartctl";
        static_configs = [ { targets = [ "127.0.0.1:9633" ]; } ];
      }
      # Self-monitoring of the local stores and Grafana. Scraped by the
      # agent instead of the stores so the results reach every stack via
      # the standard fan-out, mirroring the cluster collector.
      {
        job_name = "victoria-metrics";
        static_configs = [ { targets = [ "127.0.0.1:8428" ]; } ];
      }
      {
        job_name = "victoria-logs";
        static_configs = [ { targets = [ "127.0.0.1:9428" ]; } ];
      }
      {
        job_name = "victoria-traces";
        static_configs = [ { targets = [ "127.0.0.1:10428" ]; } ];
      }
      {
        job_name = "grafana";
        static_configs = [ { targets = [ "127.0.0.1:3000" ]; } ];
      }
    ];
  };

  # Health of the backup HDD. USB-SATA bridges often hide SMART; exporter
  # reports nothing in that case instead of failing.
  services.prometheus.exporters.smartctl = {
    enable = true;
    listenAddress = "127.0.0.1";
    # Seagate One Touch bridge blocks ATA passthrough (sat and sat,12 both
    # fail). SCSI mode yields health status and capacity only, no
    # temperature or attribute data. Enough for a disk-failing alert.
    # Pinned by-id with explicit type; the auto scan probes with sat and
    # marks the device failed.
    extraFlags = [
      "--smartctl.device=/dev/disk/by-id/usb-Seagate_One_Touch_w_PW_00000000NC1E1WXR-0:0;scsi"
    ];
  };

  # Updates enter via CI stable flake.lock PRs (update-flake-locks.yml).
  # Host only converges to origin/main; never computes own revisions.
  services.sysconf-sudo.users = [ "ops" ];
  services.sysconf-auto-pull = {
    enable = true;
    user = "ops";
    schedule = "Mon 03:00";
  };
  services.sysconf-revision.enable = true;
}

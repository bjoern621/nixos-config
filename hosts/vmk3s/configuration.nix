{ pkgs, modulesPath, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/scripts/default.nix
    ../../modules/sysconf-sudo.nix
    ../../modules/sysconf-auto-pull.nix
    ../../modules/admin-ssh-keys.nix
    ../../modules/backup-source.nix
    ../../modules/vmk3s/bitwarden-dump.nix
    # Replica exporters in the cluster collector reach the pi hh stores over
    # the tailnet. Pod traffic NATs through the host's tailscale0. Joining
    # needs a one-time `tailscale up` after deploy.
    ../../modules/tailscale-client.nix
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
  # Ports 80/443 carry public web traffic to the GitOps traefik-proxy
  # LoadBalancer (via k3s servicelb). The bundled k3s Traefik is disabled
  # below so traefik-proxy can own these host ports.
  networking.firewall.allowedTCPPorts = [
    6443
    32443
    80
    443
  ];

  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = [ "--disable=traefik" ];

    # k3s CoreDNS imports coredns-custom keys matching *.server. Pods resolve
    # via CoreDNS, not the host resolver, so MagicDNS names need this
    # explicit forward to reach the tailnet stores by ts.net FQDN.
    manifests.coredns-custom.content = {
      apiVersion = "v1";
      kind = "ConfigMap";
      metadata = {
        name = "coredns-custom";
        namespace = "kube-system";
      };
      data."ts.server" = ''
        ts.net:53 {
            errors
            cache 30
            forward . 100.100.100.100
        }
      '';
    };
  };

  environment.systemPackages = with pkgs; [
    k3s
    kubectl
    tldr
  ];

  # Backup source side. Bitwarden postgres is dumped daily at 03:00 UTC
  # into /var/backups/bitwarden/postgres.dump. The pi-backup hosts pull
  # this dump plus selected k3s PVCs via the read-only rrsync chroot at
  # /srv/backup-source. See hosts/pi-4b-hh/configuration.nix for the
  # job list and restore procedure.
  services.bitwarden-dump.enable = true;
  services.backup-source = {
    enable = true;
    sources = {
      bitwarden = "/var/backups/bitwarden";
      k3s-pvcs = "/var/lib/rancher/k3s/storage";
    };
    # Matching private key on each Pi at /home/ops/.ssh/backup_pull_id_ed25519
    # (ops:ops, 0400). One entry per Pi.
    authorizedKeys = [
      {
        name = "pi-4b-hh";
        key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINzPEPmeh9uuXE1Uo+/MfzPJfvkaMyMyRrdz4IgOLEtF pi-4b-hh";
      }
    ];
  };
}

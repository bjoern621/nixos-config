{
  lib,
  pkgs,
  modulesPath,
  ...
}:

let
  tailnet = import ../../lib/tailnet.nix;
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/scripts/default.nix
    ../../modules/sysconf-sudo.nix
    ../../modules/sysconf-auto-pull.nix
    ../../modules/sysconf-revision.nix
    ../../modules/admin-ssh-keys.nix
    ../../modules/kitty-terminfo.nix
    ../../modules/backup-source.nix
    ../../modules/vmk3s/bitwarden-dump.nix
    ../../modules/telemetry-agent.nix
    ../../modules/k3s-tailnet.nix
    ../../modules/k3s-gitlab-registry.nix
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # Host journald (k3s.service, sshd, kernel) is the one signal the
  # in-cluster DaemonSet cannot read. Forwarded via OTLP into the collector's
  # NodePort, so it inherits the full store fan-out including the pi replica.
  # hostMetrics stays off: the DaemonSet's hostmetrics against the node root
  # already reports this machine.
  services.telemetry-agent = {
    enable = true;
    hostMetrics = false;
    otlpForward = "http://127.0.0.1:30318";
  };

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Compressed swap inside the guest. A swapfile would land in the qcow2 on the
  # hypervisor SSD, where a paged-out etcd write costs milliseconds and misses
  # raft heartbeats.
  # Kubelet zeroes memory.swap.max on every container carrying a memory limit,
  # so the device backs the k3s server process, the system units beside it and
  # any container that runs without a limit.
  # 25% follows guest RAM as the domain grows.
  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };

  # zram serves one page per fault. The default of 3 decompresses 8 pages to
  # deliver one.
  boot.kernel.sysctl."vm.page-cluster" = 0;

  # Headless guest. Hypervisor QXL display serves only as recovery console.
  # Its framebuffer console exhausts device VRAM after hours of uptime.
  # Every console write then fails an eviction and logs "[TTM] Buffer eviction failed".
  # That line is itself a console write, so the failure self-sustains and floods
  # the journal telemetry-agent forwards to the cluster log store.
  # Without the driver QXL stays in VGA text mode, so the recovery console survives.
  boot.blacklistedKernelModules = [ "qxl" ];

  networking.hostName = "vmk3s";

  # CNI links churn with pods. dhcpcd chasing them logs an error burst on
  # every pod delete (dhcp_readbpf/arp_read "Network is down") and its SLAAC
  # attempts on cni0/flannel.1 fail with "ipv6_addaddr1: Invalid argument".
  networking.dhcpcd.denyInterfaces = [
    "veth*"
    "cni*"
    "flannel*"
  ];

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "de_DE.UTF-8";
  console.keyMap = "de";

  services.admin-ssh-keys.users = [ "ops" ];

  sysconf.user = "ops";
  services.sysconf-sudo.users = [ "ops" ];
  services.sysconf-auto-pull = {
    enable = true;
    user = "ops";
    schedule = "daily";
  };
  services.sysconf-revision.enable = true;

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

  # netcup-g12 joins as an agent over the tailnet. See docs/k3s-cluster.md.
  services.k3s-tailnet = {
    enable = true;
    role = "server";
  };

  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = [
      "--disable=traefik"

      # Pin the node to its stable LAN IPv4. Without --node-ip, k3s
      # auto-detects node addresses and also picks up the global IPv6 that
      # the router hands out via RA. The ISP rotates that prefix, so the
      # address later vanishes from the interface and kubelet logs "failed to
      # validate secondaryNodeIP" every status cycle. .80 is the same address
      # the traefik LoadBalancer already depends on, so it is effectively
      # static (DHCP reservation on the router).
      "--node-ip=192.168.178.80"

      # NodePorts bind loopback alone. kube-proxy DNATs a NodePort in PREROUTING,
      # so the packet takes FORWARD and the INPUT-only firewall never sees it;
      # bound to every address, a NodePort answers on netcup-g12's public one.
      # Everything using one dials 127.0.0.1: the host journald agent and the
      # net collector push OTLP to the agent on their own node.
      "--kube-proxy-arg=nodeport-addresses=127.0.0.0/8"
    ]
    # The tailnet address, for everything an off-LAN node has to reach. Absent
    # until this host's first `tailscale up`, and the server runs single-node
    # without it, so it is added rather than assumed.
    #
    # node-ip stays the LAN address above because the hostPort edge, the backup
    # pull and the local kubectl all resolve this node there.
    #
    #   node-external-ip   what flannel builds its tunnel to, given
    #                      --flannel-external-ip below.
    #   advertise-address  what the `kubernetes` Service in every namespace
    #                      points at. Left at its default it would be the LAN
    #                      address, and a pod on netcup-g12 asking for the API
    #                      would dial an address that exists in a house it is
    #                      not in.
    #   tls-san            the API server's serving certificate is presented to
    #                      an agent dialling this address, and a name not in it
    #                      is a handshake failure.
    #   flannel-iface      which interface flannel sizes its MTU against. It
    #                      picks the one holding the default route otherwise,
    #                      whose 1500 leaves a pod MTU 220 bytes wider than the
    #                      tunnel that carries it (modules/k3s-tailnet.nix).
    ++ lib.optionals (tailnet.vmk3s != null) [
      "--node-external-ip=${tailnet.vmk3s}"
      "--advertise-address=${tailnet.vmk3s}"
      "--tls-san=${tailnet.vmk3s}"
      "--flannel-external-ip"
      "--flannel-iface=tailscale0"
    ];
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

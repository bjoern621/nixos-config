{
  config,
  lib,
  ...
}:

let
  tailnet = import ../../lib/tailnet.nix;
  # The agent needs the server's address to dial it and its own to be dialled back on.
  # Neither exists before this host's first `tailscale up`, and an agent pointed at nothing
  # restarts forever, so k3s waits for both.
  joinable = tailnet.vmk3s != null && tailnet.netcup-g12 != null;
in
{
  imports = [
    ./machine.nix
    ./hardware-configuration.nix
    ../../modules/server-base.nix
    ../../modules/sops.nix
    ../../modules/scripts
    ../../modules/sysconf-checkout.nix
    ../../modules/sysconf-auto-pull.nix
    ../../modules/sysconf-revision.nix
    ../../modules/k3s-tailnet.nix
    ../../modules/telemetry-agent.nix
  ];

  sysconf.checkout.enable = true;

  services.sysconf-auto-pull = {
    enable = true;
    user = "root";
    schedule = "daily";
  };
  services.sysconf-revision.enable = true;

  time.timeZone = "Europe/Berlin";

  # No login getty on the serial console. The hypervisor exposes /dev/ttyS0
  # without a connected backend, so agetty fails isatty ("/dev/ttyS0: not a
  # tty") and Restart=always turns that into an error-log entry every 10s.
  # console=ttyS0 (modules/server-base.nix) stays for early boot output.
  systemd.services."serial-getty@ttyS0".enable = false;

  # Second node of the hh cluster, joining the vmk3s server over the tailnet.
  # See docs/k3s-cluster.md for what schedules here and how a workload asks to.
  services.k3s-tailnet = {
    enable = true;
    role = "agent";
  };

  warnings = lib.optional (
    !joinable
  ) "netcup-g12: k3s stays off until lib/tailnet.nix records both node addresses.";

  sops.secrets.k3s-agent-token.sopsFile = ../../secrets/k3s-agent.yaml;

  services.k3s = lib.mkIf joinable {
    enable = true;
    role = "agent";
    serverAddr = "https://${tailnet.vmk3s}:6443";
    tokenFile = config.sops.secrets.k3s-agent-token.path;
    extraFlags = [
      # Both are the tailnet address. node-ip is what the rest of the cluster dials this node
      # on, and eth0's public address would put the kubelet on the internet. node-external-ip
      # is what flannel builds its tunnel to, which the server's --flannel-external-ip asks
      # for.
      "--node-ip=${tailnet.netcup-g12}"
      "--node-external-ip=${tailnet.netcup-g12}"

      # Which interface flannel sizes its MTU against. It picks the one holding the
      # default route otherwise, and eth0's 1500 leaves a pod MTU 220 bytes wider than
      # the tunnel that carries it (modules/k3s-tailnet.nix).
      "--flannel-iface=tailscale0"

      # The taint is the whole placement policy: nothing runs here that did not ask to.
      # Storage is what makes it necessary. The cluster's only StorageClass is k3s'
      # local-path, whose volumes are directories on the node that first bound them, so a
      # pod holding a PVC that landed here would come up on an empty disk.
      #
      # A workload opts in with the matching toleration, and picks this node in particular
      # with nodeSelector on the label.
      "--node-label=node.hh/site=netcup"
      "--node-taint=node.hh/site=netcup:NoSchedule"
    ];
  };

  # Host journald is the one signal the in-cluster DaemonSet cannot read, and this machine's
  # own services (the relay, the group service, tailscaled) are all in it. Same shape as
  # vmk3s: forwarded via OTLP into the collector's NodePort, so it inherits the full store
  # fan-out rather than naming any store here.
  # hostMetrics stays off because the DaemonSet's hostmetrics already reports this machine.
  services.telemetry-agent = {
    enable = true;
    hostMetrics = false;
    otlpForward = "http://127.0.0.1:30318";
  };

  # What this machine exposes for the workloads pinned to it. The relay pod runs on the host
  # network, so its listeners are this host's ports and the numbers are the same ones the
  # relay's own configuration binds (argocd/applications/screenshare in hh-cluster-infra).
  #
  # Every leg here is one no reverse proxy can carry, and each is encrypted by something of
  # its own: RTSP and RTMP terminate TLS in MediaMTX, SRT is keyed by a passphrase, WebRTC
  # media is DTLS-SRTP by construction, and MoQ's session is a CONNECT over HTTP/3 that a
  # listener on TCP 443 never sees.
  #
  # Not opened, and each for its own reason:
  #   9997        the relay's API, bound to loopback and shared with the group service.
  #   8888/8889   HLS and WebRTC signalling, both loopback and both behind the pod's proxy.
  #   8893        MoQ for a native client, which no reader in the app is.
  networking.firewall.allowedTCPPorts = [
    80 # Traefik's hostPort, which redirects
    443 # Traefik's hostPort, the edge for every HTTP name pointed at this machine
    8322 # RTSPS, which carries its RTP interleaved in the TLS connection
    1936 # RTMPS
    8892 # the MoQ player page
  ];

  networking.firewall.allowedUDPPorts = [
    8890 # SRT
    8189 # WebRTC media, which negotiates a direct path and never meets a proxy
    8892 # the MoQ WebTransport session, HTTP/3 on the port the page came from
  ];

  # The lists above document what the machine answers on. They do not gate it: a published
  # container port arrives by DNAT into the pod network and is forwarded rather than
  # delivered locally, and this firewall filters INPUT alone. Turning on
  # networking.firewall.filterForward is what would make them load-bearing, and what would
  # drop every leg here until each is named in a forward rule too.
}

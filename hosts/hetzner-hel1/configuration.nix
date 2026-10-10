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
  joinable = tailnet.vmk3s != null && tailnet.hetzner-hel1 != null;
in
{
  imports = [
    ./machine.nix
    ./hardware-configuration.nix
    ../../modules/server-base.nix
    ../../modules/kitty-terminfo.nix
    ../../modules/cleanup.nix
    ../../modules/sops.nix
    ../../modules/scripts
    ../../modules/sysconf-checkout.nix
    ../../modules/sysconf-auto-pull.nix
    ../../modules/sysconf-revision.nix
    ../../modules/k3s-tailnet.nix
    ../../modules/k3s-geoip-db.nix
    ../../modules/k3s-gitlab-registry.nix
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

  # CI jobs run here and nothing else. Three job pods at the runner's 3Gi ceiling sit
  # above the 8 GiB, so idle pages of a build get somewhere to go before the kernel
  # kills the pod that holds them.
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 8 * 1024;
    }
  ];

  # Idle pages go out, pages a build is working on stay in. The default of 60 swaps a
  # working set that a CI job is about to read again.
  boot.kernel.sysctl."vm.swappiness" = 20;

  # The kubelet takes swap away from every container unless it is told otherwise.
  # LimitedSwap lends a burstable pod swap in proportion to the memory it requested,
  # which every job pod is.
  # swapBehavior has no kubelet flag, so it arrives as a configuration file the agent reads.
  environment.etc."rancher/k3s/kubelet.yaml".text = ''
    apiVersion: kubelet.config.k8s.io/v1beta1
    kind: KubeletConfiguration
    failSwapOn: false
    memorySwap:
      swapBehavior: LimitedSwap
  '';

  # Third node of the hh cluster, joining the vmk3s server over the tailnet.
  # See docs/k3s-cluster.md for what schedules here and how a workload asks to.
  services.k3s-tailnet = {
    enable = true;
    role = "agent";
  };

  warnings = lib.optional (
    !joinable
  ) "hetzner-hel1: k3s stays off until lib/tailnet.nix records both node addresses.";

  sops.secrets.k3s-agent-token.sopsFile = ../../secrets/k3s-agent.yaml;

  services.k3s = lib.mkIf joinable {
    enable = true;
    role = "agent";
    serverAddr = "https://${tailnet.vmk3s}:6443";
    tokenFile = config.sops.secrets.k3s-agent-token.path;
    extraFlags = [
      # The tailnet address: the rest of the cluster dials this node on it,
      # Cilium tunnels to it, and eth0's public address would put the kubelet on the internet.
      "--node-ip=${tailnet.hetzner-hel1}"

      # Swap on the host stops the kubelet from starting unless it is told to expect it, so
      # this flag and swapDevices above land in one activation or the node drops out.
      "--kubelet-arg=fail-swap-on=false"
      "--kubelet-arg=config=/etc/rancher/k3s/kubelet.yaml"

      # The taint is the whole placement policy: nothing runs here that did not ask to.
      # A workload opts in with the matching toleration, and picks this node in particular
      # with nodeSelector on the label. The runner manager does, for its job pods.
      "--node-label=node.hh/site=hetzner"
      "--node-taint=node.hh/site=hetzner:NoSchedule"

      # NodePorts bind loopback alone. DNAT in PREROUTING puts a NodePort on the FORWARD
      # path, past the INPUT-only firewall, and eth0 faces the internet.
      # The host journald agent dials 127.0.0.1.
      "--kube-proxy-arg=nodeport-addresses=127.0.0.0/8"
    ];
  };

  # Host journald is the one signal the in-cluster DaemonSet cannot read.
  # Same shape as the other nodes: forwarded via OTLP into the collector's NodePort,
  # so it inherits the full store fan-out rather than naming any store here.
  # hostMetrics stays off because the DaemonSet's hostmetrics already reports this machine.
  services.telemetry-agent = {
    enable = true;
    hostMetrics = false;
    otlpForward = "http://127.0.0.1:30318";
  };

  # Nothing public. The edge DaemonSet binds 80 and 443 here as on every node,
  # and no DNS record points at this address, so the firewall keeps them closed.
}

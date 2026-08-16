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
    ../../modules/mediamtx-relay.nix
    ../../modules/screenshare-groupd.nix
    ../../modules/screenshare-proxy.nix
    ../../modules/k3s-tailnet.nix
    ../../modules/telemetry-agent.nix
  ];

  sysconf.checkout.enable = true;

  services.sysconf-auto-pull = {
    enable = true;
    user = "root";
    schedule = "daily";
  };

  time.timeZone = "Europe/Berlin";

  # A CNAME onto this machine's own name, so one certificate covers the relay and the group
  # service.
  screenshare.domain = "streamrelay.bjoernblessin.de";

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
}

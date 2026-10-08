# The tailnet as k3s' node-to-node transport.
#
# The two nodes sit on different networks and one of them is behind NAT, so there is no
# address pair they reach each other on directly. Tailscale gives every node one address that
# works from both sides, and it is already this fleet's fabric.
#
# What is not here: which flags k3s takes. Those name addresses out of lib/tailnet.nix and
# differ per node, so they stay in the host configs beside the rest of that node's k3s.
#
# Ports are opened on tailscale0 alone. On netcup-g12 eth0 faces the internet, and the k3s
# API and the kubelet are the two things on that machine no stranger may reach.

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.k3s-tailnet;
in
{
  imports = [ ./tailscale-client.nix ];

  options.services.k3s-tailnet = {
    enable = lib.mkEnableOption "k3s node-to-node traffic over the tailnet";

    role = lib.mkOption {
      type = lib.types.enum [
        "server"
        "agent"
      ];
      description = ''
        Which k3s role this node runs. Decides whether the supervisor and API port is opened
        to the tailnet.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # kubelet writes the resolv.conf CoreDNS reads. MagicDNS taking that file over would move
    # every cluster lookup onto 100.100.100.100.
    services.tailscale-client.acceptDns = false;

    # Both hosts carry --node-ip on tailscale0.
    # Ordering is no gate: the interface exists as soon as the daemon is up,
    # an address arrives at login alone,
    # and a k3s that started too early restarts itself every 5s until it does.
    #
    # The pod MTU sits in the Cilium chart (hh-cluster-infra): tailscale0 is 1280
    # and the vxlan header costs 50. Detected, it would come off the default-route interface,
    # whose 1500 leaves a full-size pod packet 220 bytes too wide for the tunnel.
    # Small packets still pass, so the symptom reads as stalled TLS handshakes
    # and truncated bodies.
    systemd.services.k3s = {
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
    };

    # containerd reads /opt/cni/bin once k3s runs without flannel.
    # Cilium drops cilium-cni beside these: loopback for every sandbox,
    # portmap for the hostPort of the edge.
    systemd.tmpfiles.rules = [
      "d /opt/cni/bin 0755 root root -"
      "L+ /opt/cni/bin/loopback - - - - ${pkgs.cni-plugins}/bin/loopback"
      "L+ /opt/cni/bin/portmap - - - - ${pkgs.cni-plugins}/bin/portmap"
    ];

    # Direct node-to-node paths instead of a DERP relay. Closed, tailscale still connects and
    # every vxlan frame between the two nodes takes a detour through Tailscale's servers.
    services.tailscale.openFirewall = true;

    networking.firewall = {
      # Pods reach host-network workloads and the node's own services over these.
      trustedInterfaces = [
        "cilium_host"
        "cilium_net"
        "cilium_vxlan"
        "lxc+"
      ];

      interfaces."tailscale0" = {
        allowedTCPPorts = [
          # kubelet: the API server's exec and logs path, metrics-server, and the collector's
          # kubeletstats receiver.
          10250
          # Cilium health checks between the agents.
          4240
          # Hubble relay reading the agents.
          4244
          # Hubble metrics, scraped by the cluster collector from the other node.
          9965
        ]
        ++ lib.optional (cfg.role == "server") 6443;

        # vxlan. Encapsulated pod traffic between the nodes rides this one port.
        allowedUDPPorts = [ 8472 ];
      };
    };
  };
}

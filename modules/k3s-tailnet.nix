# The tailnet as k3s' node-to-node transport.
#
# The two nodes sit on different networks and one of them is behind NAT, so there is no
# address pair they reach each other on directly. Tailscale gives every node one address that
# works from both sides, and it is already this fleet's fabric.
#
# What is not here: which flags k3s takes. Those name addresses out of lib/tailnet.nix and
# differ per node, so they stay in the host configs beside the rest of that node's k3s.
#
# k3s ports stay closed on every interface but tailscale0: eth0 on netcup-g12 faces the internet.

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
  };

  config = lib.mkIf cfg.enable {
    # kubelet writes the resolv.conf CoreDNS reads. MagicDNS taking that file over would move
    # every cluster lookup onto 100.100.100.100.
    services.tailscale-client.acceptDns = false;

    # Static-band ClusterIP that the collector Service pins (hh-cluster-infra):
    # the host namespace resolves no cluster DNS.
    services.telemetry-agent.otlpForward = "http://10.43.0.43:4318";

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

    # The node collector (hh-cluster-infra) locates Gateway clients with this database,
    # read through its mount of the host root.
    # The mode makes a copy: a symlink would point into a store that the container lacks.
    environment.etc."geoip/city.mmdb" = {
      source = "${pkgs.callPackage ../pkgs/geoip-city-db.nix { }}/share/geoip/city.mmdb";
      mode = "0444";
    };

    # containerd reads /opt/cni/bin once k3s runs without flannel.
    # Cilium drops cilium-cni beside loopback, which every sandbox takes.
    systemd.tmpfiles.rules = [
      "d /opt/cni/bin 0755 root root -"
      "L+ /opt/cni/bin/loopback - - - - ${pkgs.cni-plugins}/bin/loopback"
    ];

    # Cilium writes a pod's security identity into the skb mark (identity << 16 | 0x0f00),
    # and the vxlan packet carrying that pod's traffic keeps it.
    # Tailscale's rules 5210-5250 send any mark matching 0x80000/0xff0000 to `main`:
    # an identity whose low byte is 0x08 would leave over the default route and reach no peer.
    # This rule ranks above them and keeps the tunnel on table 52 whatever the mark.
    systemd.services.k3s-vxlan-route = {
      description = "Route the Cilium vxlan tunnel over the tailnet whatever the packet mark";
      after = [ "tailscaled.service" ];
      before = [ "k3s.service" ];
      # Wanted, never required: a restart of this unit leaves k3s running.
      wantedBy = [
        "multi-user.target"
        "k3s.service"
      ];
      path = [ pkgs.iproute2 ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ip rule del priority 5200 2>/dev/null || true
        ip rule add priority 5200 to 100.64.0.0/10 ipproto udp dport 8472 lookup 52
      '';
      postStop = "ip rule del priority 5200 2>/dev/null || true";
    };

    # Direct node-to-node paths instead of a DERP relay. Closed, tailscale still connects and
    # every vxlan frame between the two nodes takes a detour through Tailscale's servers.
    services.tailscale.openFirewall = true;

    # Leaves the firewall to nixos-fw. Netfilter mode on sets all.src_valid_mark
    # (tailscale/tailscale#19796), under which the kernel drops every packet that Cilium hands to Envoy.
    services.tailscale.extraSetFlags = [ "--netfilter-mode=nodivert" ];

    networking.firewall = {
      # Replies to Cilium's Envoy carry its proxy mark, under which the reverse lookup
      # lands in Cilium's routing table and drops them.
      checkReversePath = false;

      trustedInterfaces = [
        # Tailnet policy decides who reaches a node, enforced by tailscaled.
        "tailscale0"
        # Pods reach host-network workloads and the node's own services over these.
        "cilium_host"
        "cilium_net"
        "cilium_vxlan"
        "lxc+"
      ];

      # tailscaled offers its cilium_host address as an endpoint too. A peer whose disco
      # ping gets a pong over the overlay moves WireGuard onto it, and the vxlan carrying
      # that WireGuard rides tailscale0 to the same peer: a loop that cuts the pair off
      # until tailscaled gives the endpoint up. No pong, no switch. The pod range comes
      # from k3s. Raw PREROUTING, ahead of nixos-fw's accept for that port.
      # The rule outlives a reload, hence the check first.
      extraCommands = ''
        iptables -t raw -C PREROUTING -s 10.42.0.0/16 -p udp --dport ${toString config.services.tailscale.port} -j DROP 2>/dev/null \
          || iptables -t raw -I PREROUTING 1 -s 10.42.0.0/16 -p udp --dport ${toString config.services.tailscale.port} -j DROP
      '';
      extraStopCommands = ''
        iptables -t raw -D PREROUTING -s 10.42.0.0/16 -p udp --dport ${toString config.services.tailscale.port} -j DROP 2>/dev/null || true
      '';
    };
  };
}

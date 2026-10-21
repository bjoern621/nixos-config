{ config, ... }:

# The travel VPN, on the host so it outlives anything the cluster does.
# WireGuard answers on UDP 51820, which the FRITZ!Box forwards.
# A network that blocks the UDP reaches the same server through wstunnel,
# behind Gateway hh at assets.bjoernblessin.de/tunnel (hh-cluster-infra, edge app).
# Clients reach the internet and the house LAN, never the cluster's pod, Service or tailnet ranges.
#
# A new client: generate its key pair, append a peer below with the next /32.

let
  lan = "enp1s0";
  # Gateway hh's EndpointSlice for wstunnel names this address and port.
  wstunnelListen = {
    host = "192.168.178.80";
    port = 8080;
  };
in
{
  sops.secrets.wireguard-server-key = {
    sopsFile = ../../secrets/wireguard-server.yaml;
    key = "private-key";
  };

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.13.13.1/24" ];
    listenPort = 51820;
    privateKeyFile = config.sops.secrets.wireguard-server-key.path;
    peers = [
      # nixos and fractal, through modules/wireguard-wstunnel.nix and the NetworkManager profile.
      {
        publicKey = "Pd2zMOQ6jPUoici9J/cycNtZRF6jZhAdHCFHnob4eX8=";
        allowedIPs = [ "10.13.13.2/32" ];
      }
    ];
  };

  networking.nat = {
    enable = true;
    internalInterfaces = [ "wg0" ];
    externalInterface = lan;
  };

  networking.firewall = {
    allowedUDPPorts = [ 51820 ];
    # Own chain, flushed on every firewall start, so a reload adds no duplicate.
    extraCommands = ''
      iptables -N travel-vpn 2>/dev/null || iptables -F travel-vpn
      iptables -A travel-vpn -d 10.42.0.0/16 -j DROP
      iptables -A travel-vpn -d 10.43.0.0/16 -j DROP
      iptables -A travel-vpn -d 100.64.0.0/10 -j DROP
      iptables -C FORWARD -i wg0 -j travel-vpn 2>/dev/null || iptables -I FORWARD -i wg0 -j travel-vpn
    '';
    extraStopCommands = ''
      iptables -D FORWARD -i wg0 -j travel-vpn 2>/dev/null || true
      iptables -F travel-vpn 2>/dev/null || true
      iptables -X travel-vpn 2>/dev/null || true
    '';
  };

  # Plain ws on the LAN address, closed in the firewall: Envoy on this host terminates TLS and dials it locally.
  # --restrict-to holds it to the WireGuard listener, and the path prefix keeps a bare probe from upgrading.
  services.wstunnel.enable = true;
  services.wstunnel.servers.travel-vpn = {
    listen = wstunnelListen // {
      enableHTTPS = false;
    };
    settings = {
      restrict-to = [
        {
          host = "127.0.0.1";
          port = 51820;
        }
      ];
      restrict-http-upgrade-path-prefix = "tunnel";
    };
  };
}

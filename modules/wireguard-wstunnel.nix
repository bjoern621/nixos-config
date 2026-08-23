{
  config,
  pkgs,
  lib,
  ...
}:

# WireGuard carried over wstunnel. The same tunnel and key as the plain WireGuard NM
# profile, wrapped in a TLS websocket so a network that blocks WireGuard's UDP still
# passes it. wstunnel carries the UDP over wss to assets.bjoernblessin.de, where the
# cluster's wireguard pod (hh-cluster-infra) unwraps it back to the WireGuard server.
# Full tunnel: every packet exits the house.
#
# NetworkManager cannot host wstunnel, so the quickshell bar toggles it like Tailscale.
# Starting wg-quick-wg-wstunnel pulls in the carrier; stopping it drops both.
#
# Change the client key: sops secrets/wireguard-client.yaml

let
  serverPublicKey = "O8K9nh7VcPeedXSpiglk59u6vaPJY8zPnyU3QmuFNzA=";
  # The edge that terminates the disguise, a CNAME to the house dynamic-DNS name.
  wssHost = "assets.bjoernblessin.de";
  pathPrefix = "tunnel";
  # wstunnel's local listener. The interface dials this instead of a public UDP port.
  carrierPort = 51821;
in
{
  environment.systemPackages = [
    pkgs.wstunnel
    pkgs.wireguard-tools
  ];

  sops.secrets.wireguard-client-key = {
    sopsFile = ../secrets/wireguard-client.yaml;
    key = "private-key";
  };

  systemd.services.wg-wstunnel-carrier = {
    description = "wstunnel carrier for the WireGuard-over-wss tunnel";
    partOf = [ "wg-quick-wg-wstunnel.service" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "simple";
      # Pin a host route to the edge before the full-tunnel interface takes the default
      # route. wg-quick's `suppress_prefixlength 0` rule lets this /32 in the main table
      # win, so the carrier's own packets skip the tunnel instead of looping into it.
      ExecStartPre = pkgs.writeShellScript "wg-wstunnel-carrier-route-up" ''
        set -eu
        ip=$(${pkgs.getent}/bin/getent ahostsv4 ${wssHost} | ${pkgs.gawk}/bin/awk 'NR==1{print $1}')
        gw=$(${pkgs.iproute2}/bin/ip route show default | ${pkgs.gawk}/bin/awk '/default/{print $3; exit}')
        dev=$(${pkgs.iproute2}/bin/ip route show default | ${pkgs.gawk}/bin/awk '/default/{print $5; exit}')
        [ -n "$ip" ] && [ -n "$gw" ] || { echo "no default route or no address for ${wssHost}"; exit 1; }
        echo "$ip" > /run/wg-wstunnel-carrier-ip
        ${pkgs.iproute2}/bin/ip route replace "$ip/32" via "$gw" dev "$dev"
      '';
      # Dials the pinned IP, not the name: wstunnel resolves per connection attempt, and
      # once the interface is up the resolver is exclusive to a DNS server behind the very
      # tunnel wstunnel carries. SNI and Host keep the disguise and the edge routing.
      ExecStart = pkgs.writeShellScript "wg-wstunnel-carrier-run" ''
        ip=$(cat /run/wg-wstunnel-carrier-ip)
        exec ${pkgs.wstunnel}/bin/wstunnel client \
          -L udp://127.0.0.1:${toString carrierPort}:127.0.0.1:51820 \
          --http-upgrade-path-prefix ${pathPrefix} \
          --tls-sni-override ${wssHost} \
          --http-headers "Host: ${wssHost}" \
          "wss://$ip:443"
      '';
      ExecStopPost = pkgs.writeShellScript "wg-wstunnel-carrier-route-down" ''
        ip=$(cat /run/wg-wstunnel-carrier-ip 2>/dev/null || true)
        [ -n "$ip" ] && ${pkgs.iproute2}/bin/ip route del "$ip/32" 2>/dev/null || true
      '';
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  networking.wg-quick.interfaces.wg-wstunnel = {
    privateKeyFile = config.sops.secrets.wireguard-client-key.path;
    address = [ "10.13.13.2/24" ];
    dns = [ "1.1.1.1" ];
    # Server side derives 1150 from its pod interface. wg-quick here would derive ~65k
    # from the loopback endpoint, and inner packets that size die on the server's egress.
    mtu = 1150;
    peers = [
      {
        publicKey = serverPublicKey;
        endpoint = "127.0.0.1:${toString carrierPort}";
        allowedIPs = [ "0.0.0.0/0" ];
        persistentKeepalive = 25;
      }
    ];
  };

  # wg-quick generates this unit. Pull the carrier in, order after it, and keep the whole
  # thing off at boot so the bar owns its lifecycle. Requires, not wants: a carrier that
  # fails to start must fail the toggle, or the interface comes up routing every packet
  # into a loopback endpoint nobody listens on.
  systemd.services."wg-quick-wg-wstunnel" = {
    requires = [ "wg-wstunnel-carrier.service" ];
    after = [ "wg-wstunnel-carrier.service" ];
    wantedBy = lib.mkForce [ ];
  };

  # NM synthesizes an "external" connection for the interface while it is up, which the
  # bar would list as a second row beside its own toggle.
  networking.networkmanager.unmanaged = [ "interface-name:wg-wstunnel" ];

  # The bar backend runs as the user; scope the toggle to this one unit and operator.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "wg-quick-wg-wstunnel.service" &&
          subject.user == "bjoern") {
        return polkit.Result.YES;
      }
    });
  '';
}

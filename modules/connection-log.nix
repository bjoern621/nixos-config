{
  config,
  lib,
  pkgs,
  ...
}:

# Inbound connection log: every new connection to this host lands in the
# journal as a kernel line, and the telemetry agent turns it into
# source/destination fields plus the service behind the port.
# Grafana's network flow dashboard reads those fields.

let
  cfg = config.services.connection-log;

  geoipDb = pkgs.callPackage ../pkgs/geoip-city-db.nix { };

  # One statement per known port.
  # Unmapped ports fall back to "<transport>/<port>" below.
  serviceStatements = lib.mapAttrsToList (
    port: service:
    ''set(attributes["destination.service"], "${service}") where attributes["destination.port"] == "${port}"''
  ) cfg.services;
in
{
  options.services.connection-log = {
    enable = lib.mkEnableOption "logging of new inbound connections, parsed by the telemetry agent";

    rateLimit = lib.mkOption {
      type = lib.types.str;
      default = "20/second";
      description = "iptables `limit` match for the log rule. A scan past it goes unlogged, the connections themselves pass.";
    };

    ignoredInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "lo"
        "cilium_host"
        "cilium_net"
        "cilium_vxlan"
        "lxc+"
        "veth+"
        "docker0"
        "br-+"
      ];
      description = "Interfaces whose traffic stays unlogged: loopback, pod and container devices. iptables `+` wildcard.";
    };

    ignoredUdpPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ 8472 ];
      description = "UDP destination ports left unlogged. VXLAN picks a fresh source port per inner flow, so each one counts as a new connection.";
    };

    services = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        "22" = "ssh";
      };
      description = "Destination port to service name, shown beside each connection.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.connection-log.services = {
      "22" = "ssh";
      "53" = "dns";
      "80" = "http";
      "443" = "https";
      "137" = "netbios";
      "138" = "netbios";
      "139" = "samba";
      "445" = "samba";
      "3000" = "grafana";
      "3702" = "wsdd";
      "3901" = "garage-rpc";
      "5353" = "mdns";
      "5355" = "llmnr";
      "5357" = "wsdd";
      "6443" = "k3s-api";
      "8081" = "smokeping";
      "8428" = "victoria-metrics";
      "8472" = "vxlan";
      "9428" = "victoria-logs";
      "10250" = "kubelet";
      "10428" = "victoria-traces";
      "41641" = "tailscale";
      "51820" = "wireguard";
    };

    # mangle INPUT sees every locally delivered packet before filter INPUT,
    # where tailscale's ts-input accepts tailnet traffic ahead of nixos-fw.
    # addrtype LOCAL keeps broadcast and multicast out.
    networking.firewall.extraCommands = ''
      while ip46tables -t mangle -D INPUT -j nixos-conn-log 2>/dev/null; do :; done
      ip46tables -t mangle -N nixos-conn-log 2>/dev/null || ip46tables -t mangle -F nixos-conn-log
      ${lib.concatMapStrings (iface: ''
        ip46tables -t mangle -A nixos-conn-log -i ${iface} -j RETURN
      '') cfg.ignoredInterfaces}
      ${lib.concatMapStrings (port: ''
        ip46tables -t mangle -A nixos-conn-log -p udp --dport ${toString port} -j RETURN
      '') cfg.ignoredUdpPorts}
      ip46tables -t mangle -A nixos-conn-log \
        -m conntrack --ctstate NEW -m addrtype --dst-type LOCAL \
        -m limit --limit ${cfg.rateLimit} --limit-burst 100 \
        -j LOG --log-level info --log-prefix "conn-new: "
      ip46tables -t mangle -I INPUT 1 -j nixos-conn-log
    '';

    networking.firewall.extraStopCommands = ''
      while ip46tables -t mangle -D INPUT -j nixos-conn-log 2>/dev/null; do :; done
      ip46tables -t mangle -F nixos-conn-log 2>/dev/null || true
      ip46tables -t mangle -X nixos-conn-log 2>/dev/null || true
    '';

    services.telemetry-agent.logProcessors = [
      {
        # "conn-new: " from the rule above, "refused connection: " from nixos-fw
        # (networking.firewall.logRefusedConnections).
        # Line: IN=eth0 OUT= MAC=... SRC=1.2.3.4 DST=5.6.7.8 ... PROTO=TCP SPT=51234 DPT=22 ...
        name = "transform/conn-log";
        settings = {
          error_mode = "ignore";
          log_statements = [
            {
              context = "log";
              conditions = [ ''IsMatch(body, "^(conn-new|refused connection): IN=")'' ];
              statements = [
                ''merge_maps(attributes, ExtractPatterns(body, "^(?P<conn_event>conn-new|refused connection): IN=(?P<conn_iface>[^ ]*) .*?SRC=(?P<conn_src>[^ ]+) DST=(?P<conn_dst>[^ ]+) .*?PROTO=(?P<conn_proto>[^ ]+)"), "upsert")''
                ''merge_maps(attributes, ExtractPatterns(body, " SPT=(?P<conn_spt>[0-9]+) DPT=(?P<conn_dpt>[0-9]+)"), "upsert") where IsMatch(body, " DPT=[0-9]")''
                ''set(attributes["conn.event"], "new") where attributes["conn_event"] == "conn-new"''
                ''set(attributes["conn.event"], "refused") where attributes["conn_event"] == "refused connection"''
                ''set(attributes["source.address"], attributes["conn_src"])''
                ''set(attributes["destination.address"], attributes["conn_dst"])''
                ''set(attributes["source.port"], attributes["conn_spt"]) where attributes["conn_spt"] != nil''
                ''set(attributes["destination.port"], attributes["conn_dpt"]) where attributes["conn_dpt"] != nil''
                ''set(attributes["network.transport"], ConvertCase(attributes["conn_proto"], "lower"))''
                ''set(attributes["network.interface.name"], attributes["conn_iface"])''
                ''delete_matching_keys(attributes, "^conn_")''
                # Tailnet: 100.64.0.0/10 and Tailscale's fd7a:115c:a1e0::/48.
                ''set(attributes["source.network"], "internet")''
                ''set(attributes["source.network"], "lan") where IsMatch(attributes["source.address"], "^(10\\.|192\\.168\\.|172\\.(1[6-9]|2[0-9]|3[01])\\.|fe80:|fd[0-9a-f]{2}:)")''
                ''set(attributes["source.network"], "tailnet") where IsMatch(attributes["source.address"], "^(100\\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\\.|fd7a:115c:a1e0:)")''
              ]
              ++ serviceStatements
              ++ [
                ''set(attributes["destination.service"], Concat([attributes["network.transport"], attributes["destination.port"]], "/")) where attributes["destination.service"] == nil and attributes["destination.port"] != nil''
                ''set(attributes["destination.service"], attributes["network.transport"]) where attributes["destination.service"] == nil''
                ''set(body, Format("%s %s %s:%s -> %s:%s %s on %s", [attributes["conn.event"], attributes["network.transport"], attributes["source.address"], attributes["source.port"], attributes["destination.address"], attributes["destination.port"], attributes["destination.service"], attributes["network.interface.name"]])) where attributes["destination.port"] != nil''
                ''set(body, Format("%s %s %s -> %s on %s", [attributes["conn.event"], attributes["network.transport"], attributes["source.address"], attributes["destination.address"], attributes["network.interface.name"]])) where attributes["destination.port"] == nil''
              ];
            }
          ];
        };
      }
      {
        # Private and tailnet sources find no entry and stay unlocated.
        name = "geoip/conn-log";
        settings = {
          context = "record";
          attributes = [ "source.address" ];
          error_mode = "silent";
          providers.maxmind.database_path = "${geoipDb}/share/geoip/city.mmdb";
        };
      }
    ];
  };
}

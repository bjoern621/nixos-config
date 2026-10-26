{
  config,
  lib,
  pkgs,
  ...
}:

# Inbound drop list: static networks from Nix plus CrowdSec decisions.
# Detection runs in cluster CrowdSec, fed from VictoriaLogs.
# Host runs firewall bouncer alone, filling ipsets from cluster LAPI.
# raw PREROUTING drops before conntrack and connection log.

let
  cfg = config.services.blocklist;
  bouncer = config.services.crowdsec-firewall-bouncer.settings;

  isIPv6 = lib.hasInfix ":";
  staticV4 = lib.filter (net: !isIPv6 net) cfg.networks;
  staticV6 = lib.filter isIPv6 cfg.networks;

  exemptV4 = [
    "127.0.0.0/8"
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "169.254.0.0/16"
    "100.64.0.0/10"
  ]
  ++ lib.filter (net: !isIPv6 net) cfg.neverBlock;
  exemptV6 = [
    "::1/128"
    "fc00::/7"
    "fe80::/10"
    "fd7a:115c:a1e0::/48"
  ]
  ++ lib.filter isIPv6 cfg.neverBlock;

  fillStaticSet = name: family: nets: ''
    ipset create -exist ${name} hash:net family ${family}
    ipset flush ${name}
    ${lib.concatMapStrings (net: ''
      ipset add -exist ${name} ${net}
    '') nets}
  '';

  # Timeout support lets bouncer set per-entry expiry; 0 keeps entries without one.
  # maxelem matches bouncer's ipset_size default.
  createBouncerSet = name: family: ''
    ipset create -exist ${name} hash:net family ${family} timeout 0 maxelem 131072
  '';

  # MagicDNS resolver.
  # k3s nodes run tailscale with --accept-dns=false, system resolver misses *.ts.net.
  tailnetResolvConf = pkgs.writeText "crowdsec-bouncer-resolv.conf" ''
    nameserver 100.100.100.100
  '';
in
{
  imports = [ ./sops.nix ];

  options.services.blocklist = {
    enable = lib.mkEnableOption "inbound drop list from static networks and CrowdSec decisions";

    networks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "192.0.2.0/24"
        "2001:db8::/32"
      ];
      description = "CIDRs dropped on every port, permanently. IPv4 and IPv6 mixed.";
    };

    neverBlock = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "159.195.203.244/32"
        "2.29.45.107/32"
      ];
      description = "CIDRs passed even when a set lists them. Defaults: public addresses of netcup-g12 and hetzner-hel1.";
    };

    lapiUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://crowdsec-lapi.tail598964.ts.net:8080";
      description = "CrowdSec LAPI the bouncer pulls decisions from. Resolved through MagicDNS.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Spoof STUN at coturn, which reflects answers at them.
    services.blocklist.networks = [
      "45.137.227.0/24"
      "213.156.101.0/24"
    ];

    networking.firewall.extraPackages = [ pkgs.ipset ];

    # Bouncer sets: create only, never flush.
    # Bouncer fills them once from a full LAPI stream, then applies deltas.
    # Reload runs extraStopCommands too: destroying them there would leave them empty until bouncer restarts.
    # Firewall stop and restart reach bouncer through PartOf; bouncer refills on start.
    networking.firewall.extraCommands = ''
      # One-shot removal of netcup-g12's nixos-stun-block. Drop once every host has deployed this.
      while iptables -t raw -D PREROUTING -j nixos-stun-block 2>/dev/null; do :; done
      iptables -t raw -F nixos-stun-block 2>/dev/null || true
      iptables -t raw -X nixos-stun-block 2>/dev/null || true

      ${fillStaticSet "blocklist-static" "inet" staticV4}
      ${fillStaticSet "blocklist-static6" "inet6" staticV6}
      ${createBouncerSet bouncer.blacklists_ipv4 "inet"}
      ${createBouncerSet bouncer.blacklists_ipv6 "inet6"}

      while ip46tables -t raw -D PREROUTING -j nixos-blocklist 2>/dev/null; do :; done
      ip46tables -t raw -N nixos-blocklist 2>/dev/null || ip46tables -t raw -F nixos-blocklist
      # Tailscale WireGuard arrives from peers' public addresses.
      ip46tables -t raw -A nixos-blocklist -p udp --dport ${toString config.services.tailscale.port} -j RETURN
      ${lib.concatMapStrings (net: ''
        iptables -t raw -A nixos-blocklist -s ${net} -j RETURN
      '') exemptV4}
      ${lib.concatMapStrings (net: ''
        ip6tables -t raw -A nixos-blocklist -s ${net} -j RETURN
      '') exemptV6}
      iptables -t raw -A nixos-blocklist -m set --match-set blocklist-static src -j DROP
      iptables -t raw -A nixos-blocklist -m set --match-set ${bouncer.blacklists_ipv4} src -j DROP
      ip6tables -t raw -A nixos-blocklist -m set --match-set blocklist-static6 src -j DROP
      ip6tables -t raw -A nixos-blocklist -m set --match-set ${bouncer.blacklists_ipv6} src -j DROP
      ip46tables -t raw -I PREROUTING 1 -j nixos-blocklist
    '';

    networking.firewall.extraStopCommands = ''
      while ip46tables -t raw -D PREROUTING -j nixos-blocklist 2>/dev/null; do :; done
      ip46tables -t raw -F nixos-blocklist 2>/dev/null || true
      ip46tables -t raw -X nixos-blocklist 2>/dev/null || true
      ipset destroy blocklist-static 2>/dev/null || true
      ipset destroy blocklist-static6 2>/dev/null || true
    '';

    # Root-owned suffices: LoadCredential reads it as PID 1 for the DynamicUser bouncer.
    sops.secrets.crowdsec-bouncer-api-key = {
      sopsFile = ../secrets/crowdsec-bouncer.yaml;
      key = config.networking.hostName;
      restartUnits = [ "crowdsec-firewall-bouncer.service" ];
    };

    services.crowdsec-firewall-bouncer = {
      enable = true;
      createRulesets = false;
      registerBouncer.enable = false;
      secrets.apiKeyPath = config.sops.secrets.crowdsec-bouncer-api-key.path;
      settings = {
        mode = "ipset";
        api_url = cfg.lapiUrl;
        # Unset, bouncer exits on first failed LAPI connect.
        retry_initial_connect = true;
      };
    };

    systemd.services.crowdsec-firewall-bouncer = {
      after = [
        "tailscaled.service"
        "network-online.target"
      ];
      wants = [
        "tailscaled.service"
        "network-online.target"
      ];
      startLimitIntervalSec = 0;
      environment.GODEBUG = "netdns=go";
      serviceConfig = {
        Restart = "always";
        RestartSec = "30s";
        # Pure Go resolver (GODEBUG) reads this file; cgo path would ask nscd and the host resolver.
        BindReadOnlyPaths = [ "${tailnetResolvConf}:/etc/resolv.conf" ];
      };
    };
  };
}

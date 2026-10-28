{
  config,
  pkgs,
  lib,
  ...
}:

# Listed sites reachable in Chrome only through CyberGhost.
# Chrome PAC policy sends listed domains to local tinyproxy.
# Own always-on OpenVPN tunnel (tun-proxy) carries tinyproxy traffic alone, nothing else routes through it.
# Tunnel keeps working while another VPN holds the default route: its packets go out the physical uplink.
# uid rule sends tinyproxy to table 1000: default via tun-proxy, unreachable fallback below it.
# Tunnel down: fallback answers ENETUNREACH, Chrome errors instantly, no DIRECT fallback.
# Firewall confines tinyproxy egress to tun-proxy as second layer.
# Domain names still resolve via normal DNS. Connections never leak.
# Chrome policy lives here, not google-chrome.nix: PAC and proxy are one concern.
# Change tunnel credentials: sops secrets/cyberghost-proxy.yaml
#
# Unpacked extension in ./extension: per-tab proxy badge, page explaining proxy errors,
# Medium paywall redirect to archive.today.
# Loaded once by hand: chrome://extensions, Developer mode on, Load unpacked, /etc/vpn-proxy-extension.
# Chrome resolves symlinks in the loaded path, so that directory stays real.
# Files inside stay symlinks into the store and follow every rebuild after a Chrome restart.

let
  extensionFiles = builtins.attrNames (builtins.readDir ./extension);
  port = 13128;
  tunDev = "tun-proxy";
  routeTable = "1000";
  # Evaluated before Tailscale's rules (5210 to 5270): exit node never carries proxy traffic.
  rulePriority = "5000";
  # Tunnel's own packets to the CyberGhost server, pinned to the physical uplink.
  # Another VPN's default route in main would otherwise carry them, and CyberGhost drops VPN-in-VPN.
  tunnelMark = "512";
  uplinkTable = "1001";
  uplinkRulePriority = "4990";
  remoteHost = "87-1-de.cg-dialup.net";
  remotePort = 443;

  # Second-level names matched under any single-label TLD, with subdomains.
  # For sites that hop between TLDs.
  vpnNamesAnyTld = [
    "topstreamfilm"
  ];

  vpnDomains = [
    "moflix-stream.xyz"
    "streamtape.com"
    "vidoza.net"
    "filemoon.sx"
    "filemoon.to"
    "mixdrop.co"
    "mixdrop.ag"
    "supervideo.cc"
    "supervideo.tv"
    "vidmoly.to"
    "vidmoly.me"
    "luluvdo.com"
    "lulustream.com"
    "firestream.to"
    "voe.sx"
    "dood.li"
    "dood.watch"
    # archive.today redirects to any of its mirrors.
    "archive.today"
    "archive.ph"
    "archive.is"
    "archive.li"
    "archive.vn"
    "archive.md"
    "archive.fo"
  ];

  # dnsDomainIs covers subdomains, bare host == covers apex.
  hostMatch = lib.concatStringsSep " || " (
    map (d: ''host == "${d}" || dnsDomainIs(host, ".${d}")'') vpnDomains
    ++ map (n: ''/(^|\.)${n}\.[a-z]+$/.test(host)'') vpnNamesAnyTld
  );

  pac = ''
    function FindProxyForURL(url, host) {
      if (${hostMatch})
        return "PROXY 127.0.0.1:${toString port}";
      return "DIRECT";
    }
  '';

  # Extension's copy of the PAC host test, so its badge and the proxy agree.
  vpnHostsJs = pkgs.writeText "vpn-hosts.js" ''
    const dnsDomainIs = (host, domain) => host.endsWith(domain);
    const isVpnHost = (host) => ${hostMatch};
  '';

  # Chrome cannot fetch file:// PAC. As flag it silently falls back DIRECT.
  # As policy with ProxyPacMandatory it blocks all browsing. data: is the only local carrier.
  # ProxyPacMandatory: unfetchable or unparseable PAC blocks instead of falling back to DIRECT.
  chromePolicy =
    pkgs.runCommand "chrome-vpn-proxy-policy.json"
      {
        inherit pac;
        passAsFile = [ "pac" ];
      }
      ''
        b64=$(base64 -w0 < "$pacPath")
        printf '{"ProxySettings":{"ProxyMode":"pac_script","ProxyPacUrl":"data:application/x-ns-proxy-autoconfig;base64,%s","ProxyPacMandatory":true}}' "$b64" > "$out"
      '';

  secret = key: {
    sopsFile = ../../secrets/cyberghost-proxy.yaml;
    inherit key;
    restartUnits = [ "openvpn-vpn-proxy.service" ];
  };
  secretPath = name: config.sops.secrets."cyberghost-proxy-${name}".path;

  # Copies main's IPv4 defaults minus tunnel devices into uplinkTable.
  # No uplink left: table stays empty, marked packets fall through to main.
  syncUplinkTable = pkgs.writeShellScript "vpn-proxy-sync-uplink" ''
    PATH=${
      lib.makeBinPath [
        pkgs.iproute2
        pkgs.gnugrep
      ]
    }
    ip -4 route flush table ${uplinkTable} 2>/dev/null || true
    ip -4 route show default | grep -Ev ' dev (tun|tailscale|wg)| linkdown' | while read -r route; do
      ip -4 route replace $route table ${uplinkTable}
    done
  '';
in
{
  services.tinyproxy = {
    enable = true;
    settings = {
      Listen = "127.0.0.1";
      Port = port;
      Allow = "127.0.0.1";
      # Warning keeps visited hosts out of the journal. Info logs every CONNECT.
      LogLevel = "Warning";
      DisableViaHeader = true;
    };
  };

  sops.secrets = lib.listToAttrs (
    map (k: lib.nameValuePair "cyberghost-proxy-${k}" (secret k)) [
      "ca"
      "cert"
      "key"
      "auth"
    ]
  );

  # route-noexec drops pushed redirect-gateway: main table stays untouched.
  # No persist-tun: reconnect drops tun-proxy and its route, requests fail fast on the fallback meanwhile.
  # IPv6 stays on the unreachable fallback: CyberGhost tunnels IPv4 only.
  services.openvpn.servers.vpn-proxy = {
    config = ''
      client
      dev ${tunDev}
      dev-type tun
      proto udp
      remote ${remoteHost} ${toString remotePort}
      resolv-retry infinite
      nobind
      persist-key
      auth SHA256
      data-ciphers AES-256-GCM:AES-128-GCM:AES-256-CBC
      data-ciphers-fallback AES-256-CBC
      remote-cert-tls server
      ping 5
      ping-restart 30
      explicit-exit-notify 2
      route-noexec
      mark ${tunnelMark}
      ca ${secretPath "ca"}
      cert ${secretPath "cert"}
      key ${secretPath "key"}
      auth-nocache
    '';
    authUserPass = secretPath "auth";
    up = "ip route replace default dev ${tunDev} table ${routeTable}";
  };
  systemd.services.openvpn-vpn-proxy = {
    after = [ "vpn-proxy-routing.service" ];
    serviceConfig.RestartSec = "5s";
  };

  networking.networkmanager.unmanaged = [ "interface-name:${tunDev}" ];

  # Uplink changes (Wi-Fi, dock, DHCP renew, VPN up or down) re-sync uplinkTable.
  networking.networkmanager.dispatcherScripts = [
    {
      type = "basic";
      source = syncUplinkTable;
    }
  ];

  # Rule and fallback stay while tunnel down: kill switch.
  # tinyproxy requires this unit. Failed setup leaves proxy down, Chrome erroring.
  systemd.services.vpn-proxy-routing = {
    description = "Route tinyproxy traffic into the proxy VPN table";
    wantedBy = [ "multi-user.target" ];
    before = [ "tinyproxy.service" ];
    path = [
      pkgs.iproute2
      pkgs.coreutils
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      uid=$(id -u tinyproxy)
      for fam in -4 -6; do
        ip $fam rule del priority ${rulePriority} 2>/dev/null || true
        ip $fam rule add priority ${rulePriority} uidrange "$uid-$uid" lookup ${routeTable}
        ip $fam route replace unreachable default metric 4096 table ${routeTable}
      done
      ip -4 rule del priority ${uplinkRulePriority} 2>/dev/null || true
      ip -4 rule add priority ${uplinkRulePriority} fwmark ${tunnelMark} lookup ${uplinkTable}
      ${syncUplinkTable}
    '';
    preStop = ''
      for fam in -4 -6; do
        ip $fam rule del priority ${rulePriority} 2>/dev/null || true
        ip $fam route del unreachable default metric 4096 table ${routeTable} 2>/dev/null || true
      done
      ip -4 rule del priority ${uplinkRulePriority} 2>/dev/null || true
      ip -4 route flush table ${uplinkTable} 2>/dev/null || true
    '';
  };
  systemd.services.tinyproxy = {
    requires = [ "vpn-proxy-routing.service" ];
    after = [ "vpn-proxy-routing.service" ];
  };

  # lo carries the 127.0.0.1 listener side.
  # Port 53 passes on any interface: the resolver moves with tailscaled and wg-quick,
  # and the chain confines connections, never lookups.
  # tcp-reset not icmp REJECT: ICMP unreachable races the SYN-SENT socket,
  # connect only dies on the retransmit ~1s later. RST kills it in ms.
  networking.firewall = {
    extraCommands = ''
      ip46tables -N vpn-proxy-out 2>/dev/null || true
      ip46tables -F vpn-proxy-out
      ip46tables -A vpn-proxy-out -o lo -j ACCEPT
      ip46tables -A vpn-proxy-out -p udp --dport 53 -j ACCEPT
      ip46tables -A vpn-proxy-out -p tcp --dport 53 -j ACCEPT
      ip46tables -A vpn-proxy-out -o ${tunDev} -j ACCEPT
      ip46tables -A vpn-proxy-out -p tcp -j REJECT --reject-with tcp-reset
      ip46tables -A vpn-proxy-out -j REJECT
      ip46tables -D OUTPUT -m owner --uid-owner tinyproxy -j vpn-proxy-out 2>/dev/null || true
      ip46tables -A OUTPUT -m owner --uid-owner tinyproxy -j vpn-proxy-out
    '';
    extraStopCommands = ''
      ip46tables -D OUTPUT -m owner --uid-owner tinyproxy -j vpn-proxy-out 2>/dev/null || true
      ip46tables -F vpn-proxy-out 2>/dev/null || true
      ip46tables -X vpn-proxy-out 2>/dev/null || true
    '';
  };

  environment.etc = {
    "opt/chrome/policies/managed/vpn-proxy.json".source = chromePolicy;
    "vpn-proxy-extension/vpn-hosts.js".source = vpnHostsJs;
  }
  // lib.listToAttrs (
    map (
      f: lib.nameValuePair "vpn-proxy-extension/${f}" { source = ./extension + "/${f}"; }
    ) extensionFiles
  );
}

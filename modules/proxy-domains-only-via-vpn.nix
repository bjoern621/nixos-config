{ pkgs, lib, ... }:

# Listed sites reachable in Chrome only through CyberGhost.
# Chrome PAC policy sends listed domains to local tinyproxy.
# Firewall confines tinyproxy uid egress to tun*, everything else rejected.
# VPN down: kernel rejects upstream connect, Chrome errors instantly, no DIRECT fallback.
# Domain names still resolve via normal DNS when VPN down; connections never leak.
# Chrome policy lives here, not google-chrome.nix: PAC and proxy are one concern.

let
  port = 13128;
  vpnDomains = [
    "topstreamfilm.live"
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
  ];

  # dnsDomainIs covers subdomains, bare host == covers apex.
  hostMatch = lib.concatMapStringsSep " || " (
    d: ''host == "${d}" || dnsDomainIs(host, ".${d}")''
  ) vpnDomains;

  pac = ''
    function FindProxyForURL(url, host) {
      if (${hostMatch})
        return "PROXY 127.0.0.1:${toString port}";
      return "DIRECT";
    }
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

  # tun* matches only NM OpenVPN devices here: eduVPN is WireGuard, Tailscale is tailscale0.
  # lo carries the 127.0.0.1 listener side and resolved at 127.0.0.53.
  # tcp-reset not icmp REJECT: ICMP unreachable races the SYN-SENT socket,
  # connect only dies on the retransmit ~1s later. RST kills it in ms.
  networking.firewall = {
    extraCommands = ''
      ip46tables -N vpn-proxy-out 2>/dev/null || true
      ip46tables -F vpn-proxy-out
      ip46tables -A vpn-proxy-out -o lo -j ACCEPT
      ip46tables -A vpn-proxy-out -o tun+ -j ACCEPT
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

  environment.etc."opt/chrome/policies/managed/vpn-proxy.json".source = chromePolicy;
}

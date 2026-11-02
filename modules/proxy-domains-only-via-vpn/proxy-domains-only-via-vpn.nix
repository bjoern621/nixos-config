{
  pkgs,
  lib,
  ...
}:

# Listed sites reachable in Chrome only while a CyberGhost VPN (networkmanager-openvpn.nix) is connected.
# Chrome PAC policy sends listed domains to local tinyproxy.
# Firewall lets tinyproxy out through tun-cyberghost alone.
# VPN down: connect gets TCP reset, Chrome errors instantly, no DIRECT fallback.
# VPN up: default route carries all traffic, embeds and links of listed sites included.
# vpn-kill-switch.nix keeps that traffic in after unexpected drop.
# Domain names still resolve via normal DNS. Connections never leak.
# Chrome policy lives here, not google-chrome.nix: PAC and proxy are one concern.
#
# Unpacked extension in ./extension: per-tab proxy badge, page explaining proxy errors,
# Medium paywall redirect to archive.today.
# Loaded once by hand: chrome://extensions, Developer mode on, Load unpacked, /etc/vpn-proxy-extension.
# Chrome resolves symlinks in the loaded path, so that directory stays real.
# Files get copied, not symlinked: Chrome skips a content script that links outside the extension directory.
# Each rebuild rewrites them. Chrome picks them up on extension reload or restart.

let
  extensionFiles = builtins.attrNames (builtins.readDir ./extension);
  port = 13128;
  tunDev = "tun-cyberghost";
  streamAggregators = import ./stream-aggregators.nix;

  # Second-level names matched under any single-label TLD, with subdomains.
  # For sites that hop between TLDs.
  vpnNamesAnyTld = [
    "topstreamfilm"
    "streamtape"
    "filemoon"
    "mixdrop"
    "supervideo"
    "vidmoly"
    "dood"
  ]
  ++ streamAggregators.namesAnyTld;

  vpnDomains = [
    "moflix-stream.xyz"
    "vidoza.net"
    "luluvdo.com"
    "lulustream.com"
    "firestream.to"
    "voe.sx"
    "fmhy.net"
    # archive.today redirects to any of its mirrors.
    "archive.today"
    "archive.ph"
    "archive.is"
    "archive.li"
    "archive.vn"
    "archive.md"
    "archive.fo"
  ]
  ++ streamAggregators.domains;

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

  extensionSources = lib.genAttrs extensionFiles (f: ./extension + "/${f}") // {
    "vpn-hosts.js" = vpnHostsJs;
  };

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
  }
  // lib.mapAttrs' (
    f: source:
    lib.nameValuePair "vpn-proxy-extension/${f}" {
      inherit source;
      mode = "0444";
    }
  ) extensionSources;
}

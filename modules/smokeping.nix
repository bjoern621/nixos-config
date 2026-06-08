{ ... }:

{
  services.smokeping = {
    enable = true;
    host = "0.0.0.0";
    port = 8081;

    # cgiUrl and imgUrl are embedded in generated HTML, so they must be
    # reachable by the browser - not localhost. pi-4b-hh resolves via
    # Tailscale MagicDNS from any host on the tailnet.
    cgiUrl = "http://pi-4b-hh:8081/smokeping/smokeping.cgi";
    imgUrl = "http://pi-4b-hh:8081/smokeping/img";

    targetConfig = ''
      probe = FPing

      menu = Top
      title = Network Latency
      remark = Continuous latency and packet-loss probes

      + Internet
      menu = Internet
      title = Internet

      ++ Cloudflare
      menu = Cloudflare (1.1.1.1)
      title = Cloudflare DNS
      host = 1.1.1.1

      ++ Google
      menu = Google (8.8.8.8)
      title = Google DNS
      host = 8.8.8.8

      ++ Quad9
      menu = Quad9 (9.9.9.9)
      title = Quad9 DNS
      host = 9.9.9.9

      ++ Heise
      menu = heise.de
      title = heise.de
      host = heise.de
    '';
  };

  networking.firewall.allowedTCPPorts = [ 8081 ];
}

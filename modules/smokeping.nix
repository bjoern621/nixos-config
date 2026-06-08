{ config, pkgs, ... }:

{
  services.smokeping = {
    enable = true;
    hostName = "pi-4b-hh";

    # The nginx virtualHost serves the CGI at /smokeping.fcgi, not /smokeping.cgi.
    cgiUrl = "http://pi-4b-hh:8081/smokeping.fcgi";

    probeConfig = ''
      + FPing
      binary = ${config.security.wrapperDir}/fping

      + DNS
      binary = ${pkgs.dig}/bin/dig
      lookup = heise.de
      pings = 5
      step = 300
      timeout = 3
    '';

    targetConfig = ''
      probe = FPing

      menu = Top
      title = Network Latency
      remark = Continuous latency and packet-loss probes

      + Local
      menu = Local
      title = LAN Baseline (control)

      ++ Router
      menu = Fritz!Box (192.168.178.1)
      title = Fritz!Box LAN side
      host = 192.168.178.1

      + Germany
      menu = Germany
      title = German Hosts

      ++ Heise
      menu = heise.de
      title = heise.de
      host = heise.de

      ++ ARD
      menu = ard.de
      title = ARD (German public broadcaster)
      host = ard.de

      ++ CCC
      menu = ccc.de
      title = Chaos Computer Club
      host = ccc.de

      + Internet
      menu = Internet
      title = International Hosts

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

      ++ GoogleDE
      menu = google.de
      title = Google Germany edge
      host = google.de

      ++ AmazonDE
      menu = amazon.de
      title = Amazon Germany
      host = amazon.de

      + DNS
      menu = DNS Latency
      title = DNS Query Times
      probe = DNS

      ++ CloudflareDNS
      menu = Cloudflare (1.1.1.1)
      title = DNS via Cloudflare
      host = 1.1.1.1

      ++ GoogleDNS
      menu = Google (8.8.8.8)
      title = DNS via Google
      host = 8.8.8.8
    '';
  };

  services.nginx.virtualHosts.smokeping.listen = [
    {
      addr = "0.0.0.0";
      port = 8081;
    }
  ];

  networking.firewall.allowedTCPPorts = [ 8081 ];
}

{ ... }:

# DNS via systemd-resolved.
# Persists eduVPN split-DNS fix. Stops FritzBox IPv6 resolvers stalling lookups.
#
# eduVPN (HAW Hamburg): Tailscale in plain resolvconf mode claims /etc/resolv.conf
# exclusively, forwards every query to HAW-internal resolvers outside the tunnel.
# Kills all name resolution while VPN up.
# systemd-resolved does per-link split DNS instead.
# ts.net -> Tailscale 100.100.100.100. Everything else -> physical uplink.
# Memory: eduvpn-tailscale-dns.
#
# ipv6.ignore-auto-dns: FritzBox advertises three resolvers over RA/DHCP.
# IPv4 192.168.178.1 stable. ULA fd66::... and GUA 2a04:4540:.../64 not.
# GUA /64 rotates on every wilhelm.tel prefix re-delegation.
# ULA neighbor entry intermittently goes FAILED.
# resolved round-robins onto the dead IPv6 server, stalls until failover.
# Symptom: lookups randomly fail "Name or service not known", raw IP keeps working.
# Dropping auto IPv6 DNS leaves only the stable IPv4 resolver.
# AAAA still resolves over IPv4 transport. IPv6 data connectivity unaffected.
# VPN-pushed DNS is set explicitly not "auto", so eduVPN + Tailscale split-DNS untouched.

{
  services.resolved = {
    enable = true;
    # DNSSEC validation failures surface as intermittent SERVFAIL. Keep off.
    settings.Resolve.DNSSEC = "false";
  };

  networking.networkmanager.dns = "systemd-resolved";

  # [connection] default: ignore RA/DHCPv6-supplied IPv6 DNS on every connection.
  networking.networkmanager.connectionConfig."ipv6.ignore-auto-dns" = true;
}

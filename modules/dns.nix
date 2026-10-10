{ ... }:

# DNS stays with tailscaled: it claims /etc/resolv.conf,
# answers MagicDNS itself and forwards the rest to the resolvers NM saw.
# An answer comes back as the upstream sent it,
# so a public CNAME onto a ts.net name fails here as on Windows and Android.
# VPN-pushed resolvers go unused while that VPN is up.
#
# ipv6.ignore-auto-dns: FritzBox advertises three resolvers over RA/DHCP.
# IPv4 192.168.178.1 stable. ULA fd66::... and GUA 2a04:4540:.../64 not.
# GUA /64 rotates on every wilhelm.tel prefix re-delegation.
# ULA neighbor entry intermittently goes FAILED.
# Lookups land on the dead IPv6 server and stall until failover.
# Symptom: lookups randomly fail "Name or service not known", raw IP keeps working.
# Dropping auto IPv6 DNS leaves only the stable IPv4 resolver.
# AAAA still resolves over IPv4 transport. IPv6 data connectivity unaffected.
# VPN-pushed DNS is set explicitly, not "auto", so a VPN's resolvers stay.

{
  # [connection] default: ignore RA/DHCPv6-supplied IPv6 DNS on every connection.
  networking.networkmanager.connectionConfig."ipv6.ignore-auto-dns" = true;
}

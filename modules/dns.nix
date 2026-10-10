{ ... }:

# FritzBox advertises three resolvers over RA/DHCP: IPv4 192.168.178.1 stable,
# ULA and GUA ones not (GUA /64 rotates per prefix re-delegation, ULA neighbor goes FAILED).
# A lookup landing on a dead IPv6 resolver stalls until failover.
# VPN-pushed DNS is set explicitly, not "auto", so a VPN's resolvers stay.

{
  # [connection] default: ignore RA/DHCPv6-supplied IPv6 DNS on every connection.
  networking.networkmanager.connectionConfig."ipv6.ignore-auto-dns" = true;
}

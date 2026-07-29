# systemd-resolved replaces plain resolvconf as system DNS.
#
# Plain resolvconf: tailscaled claims /etc/resolv.conf exclusively (MagicDNS only).
# VPN-pushed DNS (eduVPN) never becomes usable.
# tailscaled forwards queries to VPN-internal resolvers outside tunnel (fwmark bypass).
# Result: every lookup times out while VPN up.
# resolved: tailscaled installs split DNS for *.ts.net only, VPN DNS binds per-link.

{
  services.resolved.enable = true;

  # NetworkManager hands per-connection DNS to resolved, not resolvconf.
  networking.networkmanager.dns = "systemd-resolved";
}

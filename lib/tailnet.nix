# Tailnet IPv4 of each host that another host addresses by number rather than by name.
#
# A device's tailnet address is stable for its lifetime, so it is written down once here and
# read from every host config that needs it.
# Names are not usable for this: the k3s nodes run tailscale with --accept-dns=false
# (modules/k3s-tailnet.nix), so MagicDNS resolves nothing on them.
#
# Tailscale assigns the address at first login, so it cannot be chosen in advance. `null` is
# what a host reads before its first `tailscale up`, and the configs that consume it leave
# k3s off rather than pointing it at nothing. Filling both entries in is what turns the
# cluster on. See docs/k3s-cluster.md.
#
#   ssh <host> tailscale ip -4

{
  vmk3s = "100.79.197.78";
  netcup-g12 = "100.69.84.4";
}

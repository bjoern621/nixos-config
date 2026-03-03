{ ... }:

/*
  Interface: IPs, DNS, and private key for this device.
  Peer: PublicKey, presharedKey, allowedIPs, endpoint — one entry per remote.

  All values are in modules/secrets/wireguard.nix (gitignored).
  privateKeyFile is used instead of privateKey to keep the private key out of the nix store.
*/

{
  imports = [ ./secrets/wireguard.nix ];
  networking.wireguard.enable = true;
}

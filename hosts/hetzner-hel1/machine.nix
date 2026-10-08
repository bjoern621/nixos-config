# Hetzner Cloud CX33 in Helsinki, the machine itself: identity, network, boot, virtualisation.
#
# Imported by the running system and by the bootstrap config, so both agree on how the
# machine is reached.
# Every value here was read off the Ubuntu image Hetzner booted first.

{ inputs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    inputs.disko.nixosModules.disko
    ./disko.nix
  ];

  networking.hostName = "hetzner-hel1";
  nixpkgs.hostPlatform = "x86_64-linux";

  # Hetzner hands out the IPv4 address, the on-link gateway and the resolvers over DHCP.
  # IPv6 comes as a static /64 with a link-local gateway, which the Cloud Console shows.
  networking.useDHCP = false;
  # Predictable names would make the one NIC ens3 or enp0s3 depending on how it is
  # enumerated. eth0 is one name for one interface.
  networking.usePredictableInterfaceNames = false;
  networking.interfaces.eth0 = {
    useDHCP = true;
    ipv6.addresses = [
      {
        address = "2a01:4f9:c01d:2517::1";
        prefixLength = 64;
      }
    ];
  };
  # Link-local gateway, so the route is only meaningful with the interface named.
  networking.defaultGateway6 = {
    address = "fe80::1";
    interface = "eth0";
  };

  # BIOS boot: Hetzner starts the x86 cloud line without UEFI firmware,
  # so GRUB writes the MBR path into the EF02 partition disko.nix declares.
  boot.loader.grub.enable = true;

  # KVM guest. The agent is how the Cloud Console shuts the machine down cleanly.
  services.qemuGuest.enable = true;

  system.stateVersion = "26.11";
}

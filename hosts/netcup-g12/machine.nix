# netcup VPS, the machine itself: identity, network, boot, virtualisation.
#
# Imported by the running system and by the bootstrap image, so both agree on how the
# machine is reached.
# Every value here was read off the running server rather than assumed.

{ modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../../modules/deploy-target.nix
  ];

  networking.hostName = "netcup-g12";
  nixpkgs.hostPlatform = "x86_64-linux";

  # netcup runs no DHCP server.
  # Address, prefix and both gateways are assigned statically and shown in SCP under
  # Network, so an interface left on DHCP comes up with no route at all.
  networking.useDHCP = false;
  # Predictable names would make the one NIC ens3 or enp0s3 depending on how it is
  # enumerated. eth0 is one name for one interface.
  networking.usePredictableInterfaceNames = false;
  networking.interfaces.eth0 = {
    ipv4.addresses = [
      {
        address = "159.195.203.244";
        prefixLength = 22;
      }
    ];
    ipv6.addresses = [
      {
        address = "2a0a:4cc0:c2:a7ce:b8dd:51ff:fe21:4bf9";
        prefixLength = 64;
      }
    ];
  };
  networking.defaultGateway = {
    address = "159.195.200.1";
    interface = "eth0";
  };
  # Link-local gateway, so the route is only meaningful with the interface named.
  networking.defaultGateway6 = {
    address = "fe80::1";
    interface = "eth0";
  };
  networking.nameservers = [
    "46.38.252.230"
    "46.38.225.230"
    "2a03:4000:0:1::e1e6"
  ];

  # SCP boots this server in UEFI mode, so the bootloader is systemd-boot on an ESP
  # rather than grub in a disk's MBR.
  # The image variant states the same thing and has to keep stating it: qemu-efi
  # writes the ESP this expects, qemu writes an MBR it cannot boot from.
  #
  # EFI variables stay untouched because the disk is written from outside the machine,
  # so there is no firmware present at install time to record a boot entry in.
  # bootctl installs the removable path EFI/BOOT/BOOTX64.EFI beside its own copy, and
  # that is what firmware boots when no NVRAM entry names a loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  # KVM guest. The agent is how SCP shuts the machine down cleanly.
  services.qemuGuest.enable = true;

  deploy.targetHost = "root@v2202608396017497611.powersrv.de";

  system.stateVersion = "26.11";
}

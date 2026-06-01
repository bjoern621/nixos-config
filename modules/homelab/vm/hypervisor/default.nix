{
  pkgs,
  ...
}:

let
  bridgeName = "br0";
  uplinkInterface = "enp3s0";
in
{
  virtualisation.libvirtd = {
    enable = true;
    onBoot = "start";
    onShutdown = "shutdown";
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = false;
      swtpm.enable = true;
    };
  };

  # br0 bridges the physical uplink to libvirt guests. It is defined as
  # NetworkManager-native profiles rather than networking.bridges because
  # NetworkManager manages the host and ignores networking.bridges: with the
  # scripted option, the uplink enslavement happens outside NM and is lost
  # whenever NM restarts (e.g. on a live `nixos-rebuild switch`), at which
  # point NM claims the uplink with an auto-generated wired connection and the
  # bridge is left with no path to the LAN. A declarative bridge-slave profile
  # keeps the uplink enslaved across NM restarts.
  #
  # no-auto-default stops NM from creating its fallback wired connection for
  # any device, so it cannot compete with the slave profile for the uplink.
  networking.networkmanager.settings.main.no-auto-default = "*";

  networking.networkmanager.ensureProfiles.profiles = {
    "${bridgeName}" = {
      connection = {
        id = bridgeName;
        type = "bridge";
        interface-name = bridgeName;
        autoconnect = true;
        autoconnect-slaves = 1;
      };
      bridge.stp = false;
      ipv4.method = "auto";
      ipv6.method = "auto";
    };

    "${bridgeName}-${uplinkInterface}" = {
      connection = {
        id = "${bridgeName}-${uplinkInterface}";
        type = "ethernet";
        interface-name = uplinkInterface;
        master = bridgeName;
        slave-type = "bridge";
        autoconnect = true;
        autoconnect-priority = 10;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    libvirt
    qemu_kvm
    virt-manager
    guestfs-tools
    cloud-utils
    bridge-utils
  ];
}

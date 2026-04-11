{
  lib,
  pkgs,
  ...
}:

let
  bridgeName = "br0";
  uplinkInterface = "enp3s0";
  useDhcp = true;
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

  networking.bridges = {
    "${bridgeName}" = {
      interfaces = [ uplinkInterface ];
    };
  };

  networking.interfaces = {
    "${bridgeName}".useDHCP = lib.mkDefault useDhcp;
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

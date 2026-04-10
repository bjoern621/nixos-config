{
  lib,
  pkgs,
  ...
}:

let
  bridgeName = "br0";
  uplinkInterface = "enp1s0";
  useDhcp = true;
  storagePoolPath = "/srv/vm/libvirt";
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

  systemd.tmpfiles.rules = [
    "d ${storagePoolPath} 0750 root libvirtd - -"
  ];

  environment.etc."homelab/libvirt-networking.txt".text = ''
    Bridge-first baseline:
    - Preferred network: attach VM interfaces to ${bridgeName}.
    - Uplink interface: ${uplinkInterface}.
    - Fallback: use libvirt default NAT network for bootstrap or isolated testing.

    VM lifecycle defaults:
    - Host boot behavior: start libvirtd and autostart-enabled domains.
    - Host shutdown behavior: cleanly shut down running domains.
    - Storage pool path intent: ${storagePoolPath}.
    - Snapshot expectation: take pre-change snapshots before risky updates.
  '';
}

{
  lib,
  pkgs,
  ...
}:

let
  vmName = "k3s";
  vmCpus = 4;
  vmMemoryMiB = 8192;
  vmDiskGiB = 80;
  bridgeName = "br0";
  imageStorageDir = "/srv/vm/images";
  vmDiskPath = "${imageStorageDir}/${vmName}.qcow2";
  vmDomainXmlPath = "/etc/homelab/vm/${vmName}/domain.xml";
  vmDomainXml = pkgs.substituteAll {
    src = ./domain.xml;
    VM_NAME = vmName;
    VM_MEMORY_MIB = toString vmMemoryMiB;
    VM_CPUS = toString vmCpus;
    QEMU_SYSTEM_X86_64 = "${pkgs.qemu_kvm}/bin/qemu-system-x86_64";
    VM_DISK_PATH = vmDiskPath;
    VM_BRIDGE = bridgeName;
  };
in
{
  environment.systemPackages = with pkgs; [
    kubectl
    k3s
    virt-manager
    cloud-utils
    jq
  ];

  systemd.tmpfiles.rules = [
    "d ${imageStorageDir} 0750 root libvirtd - -"
  ];

  environment.etc."homelab/vm/${vmName}/domain.xml".source = vmDomainXml;

  systemd.services.homelab-k3s-vm = {
    description = "Ensure declarative libvirt domain ${vmName} exists";
    after = [ "libvirtd.service" ];
    wants = [ "libvirtd.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu

      if [ ! -f ${lib.escapeShellArg vmDiskPath} ]; then
        ${pkgs.qemu}/bin/qemu-img create -f qcow2 ${lib.escapeShellArg vmDiskPath} ${toString vmDiskGiB}G
      fi

      ${pkgs.libvirt}/bin/virsh define ${lib.escapeShellArg vmDomainXmlPath}
      ${pkgs.libvirt}/bin/virsh autostart ${vmName}
    '';
  };

  environment.etc."homelab/vm/${vmName}/vm.conf".text = ''
    VM_NAME=${vmName}
    VM_CPUS=${toString vmCpus}
    VM_MEMORY_MIB=${toString vmMemoryMiB}
    VM_DISK_GIB=${toString vmDiskGiB}
    VM_BRIDGE=${bridgeName}
    VM_STORAGE_DIR=${imageStorageDir}
  '';

  environment.etc."homelab/vm/${vmName}/bootstrap.md".text = ''
    Bootstrap flow for VM ${vmName}:
    1. Rebuild host configuration so the domain is defined and autostarted.
    2. Install NixOS in the VM and enable k3s in server mode.
    3. Wait for node readiness from inside the VM: kubectl get nodes.
    4. Export kubeconfig from the VM: /etc/rancher/k3s/k3s.yaml.
    5. Install Argo CD in namespace argocd.
    6. Register GitOps root app path convention:
       - clusters/homelab/bootstrap
       - clusters/homelab/apps/{prod,stage,dev}

    Expansion path to multi-VM k3s (future, not implemented now):
    - Add dedicated control-plane and worker VMs.
    - Use external datastore for HA.
    - Introduce anti-affinity and staged upgrades.
  '';

}

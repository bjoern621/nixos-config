{
  pkgs,
  ...
}:

let
  vmName = "k3s-bootstrap";
  vmCpus = 4;
  vmMemoryMiB = 8192;
  vmDiskGiB = 80;
  bridgeName = "br0";
  imageStorageDir = "/srv/vm/images";
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

  environment.etc."homelab/k3s-vm.conf".text = ''
    VM_NAME=${vmName}
    VM_CPUS=${toString vmCpus}
    VM_MEMORY_MIB=${toString vmMemoryMiB}
    VM_DISK_GIB=${toString vmDiskGiB}
    VM_BRIDGE=${bridgeName}
    VM_STORAGE_DIR=${imageStorageDir}
  '';

  environment.etc."homelab/k3s-bootstrap.md".text = ''
    Bootstrap flow inside VM ${vmName}:
    1. Install NixOS in VM and enable k3s server mode.
    2. Wait for node readiness: kubectl get nodes.
    3. Install Argo CD in namespace argocd.
    4. Register GitOps root app path convention:
       - clusters/homelab/bootstrap
       - clusters/homelab/apps/{prod,stage,dev}

    Expansion path to multi-VM k3s (future, not implemented now):
    - Add dedicated control-plane and worker VMs.
    - Use external datastore for HA.
    - Introduce anti-affinity and staged upgrades.
  '';

  environment.shellAliases.homelab-k3s-vm-template = "echo VM=${vmName} CPUS=${toString vmCpus} RAM=${toString vmMemoryMiB}MiB DISK=${toString vmDiskGiB}GiB BRIDGE=${bridgeName}";
}

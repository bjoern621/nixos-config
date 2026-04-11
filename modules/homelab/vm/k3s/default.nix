{
  lib,
  pkgs,
  ...
}:

let
  vmName = "k3s";
  vmDiskGiB = 80;
  imageStorageDir = "/var/lib/libvirt/images";
  vmDiskPath = "${imageStorageDir}/${vmName}.qcow2";
  vmInstallerIsoPath = "${imageStorageDir}/${vmName}-installer.iso";
  vmInstallerIsoUrl = "https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso";
  vmDomainXml = pkgs.replaceVars ./domain.xml {
    QEMU_SYSTEM_X86_64 = "${pkgs.qemu_kvm}/bin/qemu-system-x86_64";
    VM_DISK_PATH = vmDiskPath;
    VM_INSTALLER_ISO_PATH = vmInstallerIsoPath;
  };
in
{
  environment.systemPackages = with pkgs; [
    kubectl
    jq
  ];

  systemd.services.k3s-vm = {
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

      # Create the VM disk once; keep existing data on subsequent runs.
      if [ ! -f ${lib.escapeShellArg vmDiskPath} ]; then
        ${pkgs.qemu}/bin/qemu-img create -f qcow2 ${lib.escapeShellArg vmDiskPath} ${toString vmDiskGiB}G
      fi

      # Download the NixOS installer ISO once so the VM can boot into the installer.
      if [ ! -f ${lib.escapeShellArg vmInstallerIsoPath} ]; then
        temp_iso=${lib.escapeShellArg "${vmInstallerIsoPath}.tmp"}
        ${pkgs.curl}/bin/curl --fail --location --output "$temp_iso" ${lib.escapeShellArg vmInstallerIsoUrl}
        ${pkgs.coreutils}/bin/mv "$temp_iso" ${lib.escapeShellArg vmInstallerIsoPath}
      fi

      # Ensure libvirt's qemu user can read/write the disk and read the ISO.
      chown qemu-libvirtd:qemu-libvirtd ${lib.escapeShellArg vmDiskPath}
      chmod 0660 ${lib.escapeShellArg vmDiskPath}
      chown qemu-libvirtd:qemu-libvirtd ${lib.escapeShellArg vmInstallerIsoPath}
      chmod 0644 ${lib.escapeShellArg vmInstallerIsoPath}

      # Recreate the domain from declarative XML so changes are always applied.
      if ${pkgs.libvirt}/bin/virsh dominfo ${lib.escapeShellArg vmName} >/dev/null 2>&1; then
        ${pkgs.libvirt}/bin/virsh destroy ${lib.escapeShellArg vmName} >/dev/null 2>&1 || true
        ${pkgs.libvirt}/bin/virsh undefine ${lib.escapeShellArg vmName}
      fi

      # Define and enable autostart for the VM.
      ${pkgs.libvirt}/bin/virsh define ${lib.escapeShellArg "${vmDomainXml}"}
      ${pkgs.libvirt}/bin/virsh autostart ${vmName}
    '';
  };

}

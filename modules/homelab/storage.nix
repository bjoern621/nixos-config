{ ... }:

let
  root = "/srv";
in
{
  systemd.tmpfiles.rules = [
    "d ${root} 0755 root root - -"
    "d ${root}/vm 0755 root root - -"
    "d ${root}/vm/libvirt 0770 root qemu-libvirtd - -"
    "d ${root}/vm/images 0770 root qemu-libvirtd - -"
    "d ${root}/media 0770 root smbshare - -"
    "d ${root}/backups 0750 root root - -"
    "d ${root}/shared 2770 root smbshare - -"
  ];

  environment.etc."homelab/storage-layout.md".text = ''
    Storage pool design baseline:
    - Recommended implementation options: ZFS datasets or Btrfs subvolumes.
    - Layout intent:
      * ${root}/vm/libvirt -> VM disks and snapshots
      * ${root}/vm/images -> cloud images and templates
      * ${root}/media -> media library
      * ${root}/backups -> host and app backups
      * ${root}/shared -> SMB exported data

    Quota and snapshot intent:
    - Apply per-dataset/subvolume quotas for vm, media, backups, shared.
    - Use frequent snapshots for vm and shared.
    - Use retention tiers for backups.
  '';
}

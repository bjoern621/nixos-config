{ ... }:

{
  boot.swraid = {
    enable = true;
    mdadmConf = ''
      ARRAY /dev/md0 metadata=1.2 UUID=77b3dd21:f46511f2:51b68193:863cc66c
    '';
  };

  # fileSystems entries are mounted automatically during boot.
  fileSystems."/srv/raid" = {
    device = "/dev/disk/by-uuid/5fe47f1d-4c73-45b7-8095-ab09e55cfb74";
    fsType = "xfs";

    options = [ "nofail" ]; # nofail keeps boot going even if this mount is unavailable.
  };

  fileSystems."/srv/ssd1" = {
    device = "/dev/disk/by-uuid/01a1a746-4571-4b2f-a1f2-c0d069fcb316";
    fsType = "ext4";
    options = [ "nofail" ];
  };
}

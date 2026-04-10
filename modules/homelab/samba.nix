{ ... }:

let
  shareName = "shared";
  sharePath = "/srv/shared";
  allowedGroup = "smbshare";
in
{
  users.groups.${allowedGroup} = { };

  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server role" = "standalone server";
        "map to guest" = "never";
        "security" = "user";
      };

      "${shareName}" = {
        "path" = sharePath;
        "browseable" = "yes";
        "writable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "@${allowedGroup}";
        "force group" = allowedGroup;
        "create mask" = "0660";
        "directory mask" = "2770";
      };
    };
  };

  services.samba-wsdd.enable = true;

  systemd.tmpfiles.rules = [
    "d ${sharePath} 2770 root ${allowedGroup} - -"
  ];
}

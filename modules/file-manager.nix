{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    nautilus
    nautilus-python # loads Python extensions from ~/.local/share/nautilus-python/extensions/
    gvfs # sftp, smb, trash and network location backends
  ];

  services.gvfs.enable = true;    # needed for trash and network browsing in Nautilus
  services.udisks2.enable = true; # needed for removable media and mounting
}

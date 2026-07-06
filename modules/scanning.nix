{ pkgs, ... }:

{
  # Scanning backend (SANE). The GUI frontend (simple-scan) is user-level
  # and lives in home/modules/scanning.nix.
  #
  # sane-airscan discovers eSCL/WSD network scanners (e.g. the HP OfficeJet
  # 3830) via mDNS; avahi is already enabled in printing.nix.
  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.sane-airscan ];
  };

  users.users.bjoern.extraGroups = [
    "scanner" # SANE device access
    "lp" # multifunction printer-scanners
  ];
}

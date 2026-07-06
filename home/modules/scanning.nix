{ pkgs, ... }:

{
  # Scanning GUI. The SANE backend is system-level and lives in
  # modules/scanning.nix.
  home.packages = with pkgs; [
    simple-scan
  ];
}

{ config, pkgs, ... }:

let
  sysconf-help = pkgs.writeShellScriptBin "sysconf-help" ''
    # Show help for all sysconf commands
    set -euo pipefail

    echo "NixOS Configuration Management Commands"
    echo "===================================="
    echo ""
    echo "Available commands:"
    echo ""
    echo "  sysconf-reload  - Sync hardware config and rebuild system"
    echo "                   Usage: sysconf-reload"
    echo ""
    echo "  sysconf-update  - Update flake inputs to latest versions"
    echo "                   Usage: sysconf-update"
    echo ""
    echo "  sysconf-pull    - Pull latest changes from git repository"
    echo "                   Usage: sysconf-pull"
    echo ""
    echo "  sysconf-help    - Show this help message"
    echo "                   Usage: sysconf-help"
    echo ""
    echo "Examples:"
    echo "  sysconf-reload           # Rebuild with current config"
    echo "  sysconf-update           # Update dependencies and rebuild"
    echo "  sysconf-pull             # Pull remote changes and rebuild"
    echo ""
  '';
in
{
  environment.systemPackages = with pkgs; [
    sysconf-help
  ];
}

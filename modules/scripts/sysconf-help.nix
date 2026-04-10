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
    echo "                   Usage: sysconf-reload [nixos|homelab]"
    echo "                   No argument: detect host from /etc/hostname"
    echo ""
    echo "  sysconf-update  - Update flake inputs to latest versions"
    echo "                   Usage: sysconf-update"
    echo ""
    echo "  sysconf-stable-update - Update ALL flake inputs to revisions that are at"
    echo "                   least 7 days old (stable/baked updates)"
    echo "                   Usage: sysconf-stable-update [days]"
    echo "                   Example: sysconf-stable-update 14  # 14-day delay"
    echo ""
    echo "  sysconf-pull    - Pull latest changes from git repository"
    echo "                   Usage: sysconf-pull"
    echo ""
    echo "  sysconf-help    - Show this help message"
    echo "                   Usage: sysconf-help"
    echo ""
    echo "Examples:"
    echo "  sysconf-reload           # Detect host and rebuild"
    echo "  sysconf-reload homelab   # Rebuild homelab explicitly"
    echo "  sysconf-update           # Update dependencies and rebuild detected host"
    echo "  sysconf-pull             # Pull remote changes and rebuild detected host"
    echo ""
  '';
in
{
  environment.systemPackages = with pkgs; [
    sysconf-help
  ];
}

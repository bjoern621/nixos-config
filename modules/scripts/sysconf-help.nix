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
    echo "  sysconf-reload  - Build a host and switch to it"
    echo "                   Usage: sysconf-reload [<host>] [--remote <ssh-target>]"
    echo "                   No argument: detect host from /etc/hostname"
    echo "                   --remote: build here, activate over ssh on the"
    echo "                   address given, which is required. An ssh alias"
    echo "                   is the short form of one."
    echo "                   A remote deploy keeps the host's committed"
    echo "                   hardware-configuration.nix rather than copying"
    echo "                   this machine's over it."
    echo ""
    echo "  sysconf-update  - Update flake inputs to latest versions"
    echo "                   Usage: sysconf-update"
    echo ""
    echo "  sysconf-pull    - Pull latest changes from git repository."
    echo "                   Fast-forwards by default and aborts on local"
    echo "                   commits. --hard resets to origin and discards them."
    echo "                   Usage: sysconf-pull [--hard]"
    echo ""
    echo "  sysconf-fix-monitors - Re-apply Hyprland monitor config to clear a"
    echo "                   mixed-scale coordinate bug (cursor wall on DP-7,"
    echo "                   bar top-edge offset on eDP-1). Run after boot,"
    echo "                   lid open/close, monitor hotplug, or suspend resume"
    echo "                   if the symptom appears."
    echo "                   Usage: sysconf-fix-monitors"
    echo ""
    echo "  sysconf-selftest - Run live health checks against the running system"
    echo "                   (lid switch, keybinds, quickshell layers). Manual"
    echo "                   tests run first, then automated ones."
    echo "                   Usage: sysconf-selftest [--list] [--no-manual] [FILTER]"
    echo ""
    echo "  sysconf-help    - Show this help message"
    echo "                   Usage: sysconf-help"
    echo ""
    echo "Examples:"
    echo "  sysconf-reload           # Detect host and rebuild"
    echo "  sysconf-reload homelab   # Rebuild homelab explicitly"
    echo "  sysconf-reload netcup-g12 --remote root@203.0.113.9  # deploy it elsewhere"
    echo "  sysconf-update           # Update dependencies and rebuild detected host"
    echo "  sysconf-pull             # Pull remote changes and rebuild detected host"
    echo "  sysconf-pull --hard      # Discard local commits, match origin, rebuild"
    echo ""
  '';
in
{
  environment.systemPackages = with pkgs; [
    sysconf-help
  ];
}

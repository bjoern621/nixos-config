# Read-only viewer for the NixOS firewall (networking.firewall, iptables backend).
# There is no GUI for the default iptables backend, so this provides a desktop
# entry that opens the active rules in a terminal.
{ pkgs, ... }:

let
  firewall-view = pkgs.writeShellScriptBin "firewall-view" ''
    set -euo pipefail

    echo "Open inbound ports (everything else is blocked):"
    echo
    (sudo iptables -S nixos-fw; sudo ip6tables -S nixos-fw) \
      | ${pkgs.gawk}/bin/awk '/--dport/ {
          for (i = 1; i <= NF; i++) {
            if ($i == "-p") proto = $(i + 1)
            if ($i == "--dport") port = $(i + 1)
          }
          print "  " proto "/" port
        }' \
      | sort -t/ -k2,2n -u

    echo
    echo "Full rule set (first block IPv4, second block IPv6):"
    echo
    sudo nixos-firewall-tool show

    echo
    read -rsn1 -p "Press any key to close..."
  '';
in
{
  home.packages = [ firewall-view ];

  xdg.desktopEntries."firewall-view" = {
    name = "Firewall";
    exec = "alacritty --title Firewall -e firewall-view";
    icon = "security-high";
    type = "Application";
    categories = [
      "Settings"
      "Security"
      "System"
    ];
    settings.Keywords = "firewall;ports;iptables;netzwerk;network";
  };
}

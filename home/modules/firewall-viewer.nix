# Read-only viewer for the NixOS firewall (networking.firewall, iptables backend).
# There is no GUI for the default iptables backend, so this provides a desktop
# entry that opens the active rules in a terminal.
{ lib, pkgs, ... }:

let
  firewall-view = pkgs.writeShellScriptBin "firewall-view" ''
    set -euo pipefail
    export PATH=${lib.makeBinPath (with pkgs; [ gawk coreutils util-linux ])}:$PATH

    echo "== NixOS Firewall =="
    echo
    echo "Open inbound ports (everything else is blocked):"
    echo

    # -S output has one rule per line ("-A nixos-fw -p tcp --dport 631 ...")
    # which is easier to parse than the columnar -L output that `show` uses.
    ports=$( (sudo iptables -S nixos-fw; sudo ip6tables -S nixos-fw) \
      | awk '/--dport/ {
          for (i = 1; i <= NF; i++) {
            if ($i == "-p") proto = $(i + 1)
            if ($i == "--dport") port = $(i + 1)
          }
          print proto "/" port
        }' \
      | sort -t/ -k2,2n -u)

    {
      echo "PROTO|PORT|SERVICE"
      echo "-----|----|-------"
      while IFS=/ read -r proto port; do
        name=$(getent services "$port/$proto" | awk '{print $1}') || true
        echo "$proto|$port|''${name:--}"
      done <<< "$ports"
    } | column -t -s'|' -o' | '

    echo
    echo "Full rule set (first block IPv4, second block IPv6):"
    echo
    sudo nixos-firewall-tool show

    echo
    nixos-firewall-tool help
    echo

    # Drop into a normal shell so commands can be run from here.
    exec "''${SHELL:-zsh}"
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

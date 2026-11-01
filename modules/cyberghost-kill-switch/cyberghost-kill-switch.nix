{
  config,
  pkgs,
  lib,
  ...
}:

# Blocks login users' traffic outside CyberGhost tunnel while armed.
# CyberGhost VPN up arms it. Deliberate disconnect releases it.
# Other drops (timeout, suspend, NM restart) keep it until reconnect or release in network menu.
# Armed means cyberghost-kill-switch.service active.
# Covers uids 1000-60000 only: OpenVPN handshakes as root before dropping to nm-openvpn,
# so system-wide block would stop reconnect. NetworkManager, tailscaled and nix stay unblocked.
# IPv6 blocked as well while armed: CyberGhost tunnels IPv4 only, IPv6 default stays on uplink.
# LAN, link-local, multicast and tailnet stay reachable: none carries public IP.

let
  device = "tun-cyberghost";
  unit = "cyberghost-kill-switch";
  chain = "cyberghost-kill-switch";
  jump = "OUTPUT -m owner --uid-owner 1000-60000 -j ${chain}";
  firewall = config.networking.firewall.package;

  watch = pkgs.writeShellApplication {
    name = "cyberghost-kill-switch-watch";
    runtimeInputs = [
      pkgs.systemd
      pkgs.jq
      pkgs.iproute2
      pkgs.util-linux
      pkgs.libnotify
      pkgs.coreutils
    ];
    text = builtins.readFile ./watch.sh;
  };
in
{
  # Chain always exists. Jump present only while armed, re-added after firewall reload.
  networking.firewall = {
    extraCommands = ''
      ip46tables -N ${chain} 2>/dev/null || true
      ip46tables -F ${chain}
      ip46tables -A ${chain} -o lo -j ACCEPT
      ip46tables -A ${chain} -o ${device} -j ACCEPT
      ip46tables -A ${chain} -o tailscale0 -j ACCEPT
      iptables -A ${chain} -d 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,224.0.0.0/4,255.255.255.255 -j ACCEPT
      ip6tables -A ${chain} -d fe80::/10,fc00::/7,ff00::/8 -j ACCEPT
      ip46tables -A ${chain} -p tcp -j REJECT --reject-with tcp-reset
      ip46tables -A ${chain} -j REJECT
      ip46tables -D ${jump} 2>/dev/null || true
      if ${pkgs.systemd}/bin/systemctl is-active --quiet ${unit}; then
        ip46tables -A ${jump}
      fi
    '';
    extraStopCommands = ''
      ip46tables -D ${jump} 2>/dev/null || true
      ip46tables -F ${chain} 2>/dev/null || true
      ip46tables -X ${chain} 2>/dev/null || true
    '';
  };

  systemd.services.${unit} = {
    description = "Block login users' traffic outside the CyberGhost tunnel";
    after = [ "firewall.service" ];
    path = [ firewall ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for ipt in iptables ip6tables; do
        $ipt -D ${jump} 2>/dev/null || true
        $ipt -A ${jump}
      done
    '';
    preStop = ''
      for ipt in iptables ip6tables; do
        $ipt -D ${jump} 2>/dev/null || true
      done
    '';
  };

  systemd.services."${unit}-watch" = {
    description = "Arm the CyberGhost kill switch when a CyberGhost VPN comes up";
    wantedBy = [ "multi-user.target" ];
    after = [
      "dbus.service"
      "firewall.service"
    ];
    environment = {
      DEVICE = device;
      UNIT = unit;
    };
    serviceConfig = {
      ExecStart = lib.getExe watch;
      Restart = "always";
      RestartSec = "2s";
    };
  };

  # Network menu arms and releases kill switch as the user.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "${unit}.service" &&
          subject.user == "${config.sysconf.user}") {
        return polkit.Result.YES;
      }
    });
  '';
}

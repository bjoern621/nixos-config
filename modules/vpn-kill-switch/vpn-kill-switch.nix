{
  config,
  pkgs,
  lib,
  ...
}:

# Blocks login users' traffic outside VPN tunnels while armed.
# Any VPN tunnel up arms it: CyberGhost, NM WireGuard profiles, WireGuard over wstunnel.
# Deliberate disconnect releases it, unless another tunnel comes up within releaseGraceSeconds.
# Network menu switches tunnels by taking old one down first, so kill switch holds across switch.
# Other drops (timeout, suspend, NM restart) keep it until reconnect or release in network menu.
# Armed means vpn-kill-switch.service active.
# Covers uids 1000-60000 only: OpenVPN handshakes as root before dropping to nm-openvpn,
# so system-wide block would stop reconnect. NetworkManager, tailscaled and nix stay unblocked.
# WireGuard handshakes from kernel socket without owner, wstunnel carrier runs as root: both pass.
# IPv6 blocked as well while armed: no tunnel here carries IPv6, IPv6 default stays on uplink.
# LAN, link-local, multicast and tailnet stay reachable: none carries public IP.

let
  # NM names WireGuard interface after imported conf file.
  # Profile whose interface matches none stays blocked while armed.
  tunnelDevices = [
    "tun-cyberghost"
    "wg+"
    "hh-cluster"
  ];
  wstunnelUnit = "wg-quick-wg-wstunnel.service";
  releaseGraceSeconds = 3;

  unit = "vpn-kill-switch";
  releaseUnit = "${unit}-release";
  chain = "vpn-kill-switch";
  jump = "OUTPUT -m owner --uid-owner 1000-60000 -j ${chain}";
  firewall = config.networking.firewall.package;

  environment = {
    UNIT = "${unit}.service";
    RELEASE_UNIT = "${releaseUnit}.service";
    WSTUNNEL_UNIT = wstunnelUnit;
    RELEASE_GRACE_SECONDS = toString releaseGraceSeconds;
  };

  script =
    name: file: runtimeInputs:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        pkgs.systemd
        pkgs.gnugrep
        config.networking.networkmanager.package
      ]
      ++ runtimeInputs;
      text = builtins.readFile ./tunnels.sh + builtins.readFile file;
    };

  watch = script "vpn-kill-switch-watch" ./watch.sh [
    pkgs.jq
    pkgs.util-linux
    pkgs.libnotify
    pkgs.coreutils
  ];
  release = script "vpn-kill-switch-release" ./release.sh [ pkgs.coreutils ];
in
{
  # Chain always exists. Jump present only while armed, re-added after firewall reload.
  networking.firewall = {
    extraCommands = ''
      ip46tables -N ${chain} 2>/dev/null || true
      ip46tables -F ${chain}
      ip46tables -A ${chain} -o lo -j ACCEPT
      ${lib.concatMapStrings (device: ''
        ip46tables -A ${chain} -o ${device} -j ACCEPT
      '') tunnelDevices}
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
    description = "Block login users' traffic outside VPN tunnels";
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

  systemd.services.${releaseUnit} = {
    description = "Release the VPN kill switch unless another tunnel takes over";
    inherit environment;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe release;
    };
  };

  systemd.services."${unit}-watch" = {
    description = "Arm the VPN kill switch when a NetworkManager VPN tunnel comes up";
    wantedBy = [ "multi-user.target" ];
    after = [
      "dbus.service"
      "firewall.service"
    ];
    inherit environment;
    serviceConfig = {
      ExecStart = lib.getExe watch;
      Restart = "always";
      RestartSec = "2s";
    };
  };

  # NM never sees wstunnel tunnel, so its unit arms and releases.
  # SERVICE_RESULT success: deliberate stop.
  # Anything else: failed start, cancels pending release like a dropped NM tunnel in watch.sh.
  systemd.services.${lib.removeSuffix ".service" wstunnelUnit} =
    lib.mkIf (config.networking.wg-quick.interfaces ? wg-wstunnel)
      {
        serviceConfig = {
          ExecStartPost = [ "${pkgs.systemd}/bin/systemctl start --no-block ${unit}.service" ];
          ExecStopPost = [
            (pkgs.writeShellScript "vpn-kill-switch-wstunnel-down" ''
              if [ "$SERVICE_RESULT" = success ]; then
                ${pkgs.systemd}/bin/systemctl start --no-block ${releaseUnit}.service
              else
                ${pkgs.systemd}/bin/systemctl stop --no-block ${releaseUnit}.service
              fi
            '')
          ];
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

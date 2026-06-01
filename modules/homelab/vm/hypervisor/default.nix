{
  pkgs,
  ...
}:

let
  bridgeName = "br0";
  uplinkInterface = "enp3s0";
  # Pin the bridge to the uplink's permanent MAC. A networkd bridge netdev
  # otherwise gets a fresh random MAC on each (re)creation, which changes the
  # DHCP identity and the host's leased address on every rebuild. Reusing the
  # uplink MAC matches the default Linux behaviour of a bridge over a single
  # port and keeps the lease stable.
  uplinkMac = "60:be:b4:14:61:b4";

  # Safety net for the guest tap. libvirt enslaves a guest's tap to br0 once, at
  # guest start, and never reconciles it. If the bridge is recreated under a
  # running guest the tap is orphaned and the guest loses the LAN. The primary
  # defence is the networkd setup below, which keeps br0 a stable netdev across a
  # rebuild and does not evict foreign bridge ports. This hook covers the
  # remaining case: on guest (re)start it re-enslaves any of the guest's taps
  # that are bridged to br0 but currently have no master.
  enslaveGuestTaps = pkgs.writeShellScript "libvirt-enslave-guest-taps" ''
    operation="$2"
    case "$operation" in
      started | reconnect) ;;
      *) exit 0 ;;
    esac

    domainXml="$(cat)"
    case "$domainXml" in
      *"bridge='${bridgeName}'"*) ;;
      *) exit 0 ;;
    esac

    taps="$(printf '%s' "$domainXml" \
      | ${pkgs.gnused}/bin/sed -n "s/.*<target dev='\(vnet[0-9]*\)'.*/\1/p")"
    for tap in $taps; do
      if [ -d "/sys/class/net/$tap" ] && [ ! -e "/sys/class/net/$tap/master" ]; then
        ${pkgs.iproute2}/bin/ip link set "$tap" master ${bridgeName}
      fi
    done
  '';
in
{
  virtualisation.libvirtd = {
    enable = true;
    onBoot = "start";
    onShutdown = "shutdown";
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = false;
      swtpm.enable = true;
    };
    hooks.qemu.enslave-guest-taps = enslaveGuestTaps;
  };

  # br0 bridges the physical uplink (enp3s0) to libvirt guests. It is managed by
  # systemd-networkd rather than NetworkManager. networkd keeps the bridge as a
  # persistent netdev: a `nixos-rebuild switch` reloads it instead of tearing it
  # down, and it leaves foreign bridge ports (the libvirt guest taps) attached.
  # NetworkManager instead reactivates its bridge profile on restart and evicts
  # ports it does not own, which detached the running guest tap and took the VM
  # offline. Scripted networking.bridges had the same teardown-on-switch problem
  # for the uplink. networkd avoids both failure modes.
  networking.useNetworkd = true;
  networking.useDHCP = false;
  networking.networkmanager.enable = false;

  systemd.network = {
    enable = true;

    netdevs."20-${bridgeName}".netdevConfig = {
      Name = bridgeName;
      Kind = "bridge";
      MACAddress = uplinkMac;
    };

    networks = {
      # Uplink: enslaved to the bridge, no address of its own. The host is
      # considered online once the link is enslaved; the address lives on br0.
      "30-${uplinkInterface}" = {
        matchConfig.Name = uplinkInterface;
        networkConfig.Bridge = bridgeName;
        linkConfig.RequiredForOnline = "enslaved";
      };

      # The bridge carries the host address via DHCP (v4 + v6) and SLAAC.
      "40-${bridgeName}" = {
        matchConfig.Name = bridgeName;
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = true;
        };
        linkConfig.RequiredForOnline = "routable";
      };
    };
  };

  environment.systemPackages = with pkgs; [
    libvirt
    qemu_kvm
    virt-manager
    guestfs-tools
    cloud-utils
    bridge-utils
  ];
}

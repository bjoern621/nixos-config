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

  # Safety net for a VM's virtual network port. When a VM starts, libvirt creates
  # a virtual port (vnet0, vnet1, ...) for it and connects it to br0 once. libvirt
  # never re-checks that connection, so if br0 is recreated while the VM is
  # running, the port is left disconnected and the VM loses the network. The main
  # protection is the networkd setup below, which keeps br0 stable across a rebuild
  # and does not remove ports that something else (libvirt) added. This hook is the
  # backup: when a VM starts, or libvirt reconnects to an already-running VM, it
  # reconnects any of that VM's br0 ports that have become disconnected.
  #
  # "master" below is the kernel's name for the bridge a port belongs to: a port
  # with no master is not attached to any bridge.
  attachGuestNics = pkgs.writeShellScript "libvirt-attach-guest-nics" ''
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

    nics="$(printf '%s' "$domainXml" \
      | ${pkgs.gnused}/bin/sed -n "s/.*<target dev='\(vnet[0-9]*\)'.*/\1/p")"
    for nic in $nics; do
      if [ -d "/sys/class/net/$nic" ] && [ ! -e "/sys/class/net/$nic/master" ]; then
        ${pkgs.iproute2}/bin/ip link set "$nic" master ${bridgeName}
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
    hooks.qemu.attach-guest-nics = attachGuestNics;
  };

  # br0 connects the physical network port (enp3s0) to the VMs. It is managed by
  # systemd-networkd rather than NetworkManager. networkd keeps the bridge as a
  # stable device: a `nixos-rebuild switch` reloads it instead of tearing it down,
  # and it does not remove ports that something else (libvirt) added to the bridge.
  # NetworkManager instead rebuilds its bridge profile on restart and removes ports
  # it does not own, which disconnected the running VM's network port and took the
  # VM offline. The older scripted networking.bridges had the same
  # teardown-on-switch problem for enp3s0. networkd avoids both failure modes.
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
      # enp3s0 is added to the bridge and has no address of its own. The host
      # counts as online once this port is attached to br0; the address lives on
      # br0. ("enslaved" is networkd's term for "attached to a bridge".)
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

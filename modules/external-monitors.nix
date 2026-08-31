{ pkgs, ... }:

# External monitors via CalDigit TS5 Plus (USB4/TB4) dock on AMD Phoenix1.
#
# Phoenix1 DPIA AUX cap probe through dock is flaky.
# Auto-negotiation sticks at HBR/HBR2 (max 1440p75/100); links train fine at HBR3 when forced.
# "4 0x1e 0" (4 lanes, HBR3) into per-connector debugfs link_settings triggers retrain.
# Enables dual 1440p144.
#
# Force gated twice:
# - TS5 Plus on thunderbolt bus. Keeps force off other docks.
#   device_name reads exactly "TS5 Plus" (vendor_name "CalDigit, Inc.").
# - is_dpia_link == "yes". Native DP and HDMI PCON negotiate fine alone.
#   Laptop HDMI PCON runs 2 lanes; forced 4-lane HBR3 never trains,
#   output stays dark while EDID still reads, so OS lists the monitor.
#
# Banned thunderbolt params: bw_alloc_mode=1, asym_threshold=0.
# Both stick link at HBR/RBR or kill training on this dock + APU combo.
#
# Risk: non-HBR3 cable behind dock fails training, output dark. Replug recovers.

let
  forceScript = pkgs.writeShellScript "amdgpu-force-hbr3" ''
    set -u
    grep -qx 'TS5 Plus' /sys/bus/thunderbolt/devices/*/device_name 2>/dev/null || exit 0
    for dir in /sys/class/drm/card*-DP-*; do
      [ -e "$dir/status" ] || continue
      [ "$(cat "$dir/status")" = "connected" ] || continue
      name=$(basename "$dir")
      [[ "$name" =~ ^card([0-9]+)-(.+)$ ]] || continue
      card_num="''${BASH_REMATCH[1]}"
      conn="''${BASH_REMATCH[2]}"
      dbg="/sys/kernel/debug/dri/$card_num/$conn"
      [ -e "$dbg/link_settings" ] || continue
      [ "$(cat "$dbg/is_dpia_link" 2>/dev/null)" = "yes" ] || continue
      echo "4 0x1e 0" > "$dbg/link_settings" 2>/dev/null || true
    done
  '';
in
{
  # thunderbolt.dprx_timeout=-1: wait indefinitely for DP RX capability read.
  # amdgpu.dcdebugmask=0x10: PSR off, works around flip_done timeouts.
  # pci=hpbussize=0x33,hpmemsize=256M: PCIe BAR sizing for USB4 hotplug.
  boot.kernelParams = [
    "thunderbolt.dprx_timeout=-1"
    "amdgpu.dcdebugmask=0x10"
    "pci=hpbussize=0x33,hpmemsize=256M"
  ];

  # Dock and DP tunnels enumerate during initrd.
  boot.initrd.kernelModules = [ "thunderbolt" ];

  services.hardware.bolt.enable = true;

  # Oneshot at boot + udev trigger on DRM change.
  systemd.services.amdgpu-force-hbr3 = {
    description = "Force HBR3 on DPIA connectors (CalDigit dock)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-settle.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = forceScript;
    };
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="drm", ACTION=="change", RUN+="${pkgs.systemd}/bin/systemctl --no-block start amdgpu-force-hbr3.service"
  '';
}

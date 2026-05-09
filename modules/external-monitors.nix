{ pkgs, ... }:

# Fixes and helpers for external monitors via the CalDigit TS5 Plus
# (USB4 / Thunderbolt 4) dock on AMD Phoenix1.
#
# Bundles:
# - kernel params (DP-RX cap-probe timeout, PSR workaround, PCIe hotplug sizing)
# - early thunderbolt module load
# - bolt (TB device authorization daemon)
# - HBR3 link rate force on every DP hotplug event, enabling dual 1440p144
#
# Background: the AMD Phoenix1 DPIA AUX cap probe through the TS5 Plus is
# flaky. Auto-negotiation gets stuck at HBR/HBR2 (max 1440p75/100) even
# though links train cleanly at HBR3 when forced. Writing "4 0x1e 0"
# (4 lanes, HBR3) to the per-connector debugfs link_settings triggers a
# re-train at HBR3.
#
# Banned thunderbolt params (do NOT add): bw_alloc_mode=1 and
# asym_threshold=0 cause the link to get stuck at HBR/RBR or fail to
# train at all on this dock + APU combo.
#
# Risk: if any DP cable in the chain is not HBR3-capable, link training
# will fail and the affected output goes dark. Replug to recover.

let
  forceScript = pkgs.writeShellScript "amdgpu-force-hbr3" ''
    set -u
    for dir in /sys/class/drm/card*-DP-*; do
      [ -e "$dir/status" ] || continue
      [ "$(cat "$dir/status")" = "connected" ] || continue
      name=$(basename "$dir")
      [[ "$name" =~ ^card([0-9]+)-(.+)$ ]] || continue
      card_num="''${BASH_REMATCH[1]}"
      conn="''${BASH_REMATCH[2]}"
      target="/sys/kernel/debug/dri/$card_num/$conn/link_settings"
      [ -e "$target" ] || continue
      echo "4 0x1e 0" > "$target" 2>/dev/null || true
    done
  '';
in
{
  # Kernel params for DisplayPort tunneling over USB4
  #
  # thunderbolt.dprx_timeout=-1   - Wait indefinitely for DP RX capability read
  #                                 (mitigates DPIA AUX cap-probe timeouts)
  # amdgpu.dcdebugmask=0x10       - Workaround for flip_done timeout issues (PSR)
  # pci=hpbussize=0x33,hpmemsize=256M - PCIe BAR sizing for USB4 hot-plug
  boot.kernelParams = [
    "thunderbolt.dprx_timeout=-1"
    "amdgpu.dcdebugmask=0x10"
    "pci=hpbussize=0x33,hpmemsize=256M"
  ];

  # Load thunderbolt early so the dock and DP tunnels enumerate during initrd
  boot.initrd.kernelModules = [ "thunderbolt" ];

  # Thunderbolt device authorization daemon
  services.hardware.bolt.enable = true;

  # HBR3 force: oneshot at boot + udev RUN+= on DP connector change
  systemd.services.amdgpu-force-hbr3 = {
    description = "Force HBR3 on connected DisplayPort connectors";
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

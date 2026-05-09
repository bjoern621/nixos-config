{ config, lib, pkgs, ... }:

let
  cfg = config.services.amdgpuForceHbr3;
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
  options.services.amdgpuForceHbr3.enable = lib.mkEnableOption ''
    forcing HBR3 link rate on connected DisplayPort outputs.

    Workaround for AMD Phoenix1 DPIA AUX cap-probe truncation through the
    CalDigit TS5 Plus dock: auto-negotiation gets stuck at HBR/HBR2 (max
    1440p75/100) even though the links train cleanly at HBR3 when forced
    via debugfs Preferred. Writing 4 lanes / 0x1e (HBR3) on every connect
    event triggers a re-train at the higher rate, enabling 1440p144.

    Risk: if any DP cable in the chain isn't HBR3-capable, link training
    will fail and the affected output goes dark. Replug to recover.
  '';

  config = lib.mkIf cfg.enable {
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
  };
}

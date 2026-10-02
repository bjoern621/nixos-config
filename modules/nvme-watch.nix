{ pkgs, ... }:

# Watch for Samsung PM9A1 controller-fatal resets (CSTS=0x3) after ASPM L1.1/L1.2 fix in power-management.nix.
# Temporary: remove once 2 quiet weeks confirm fix (from 2026-10-02).
# One line per run in /var/log/nvme-watch.log; `rg ALERT` lists bad runs.
# Runs as root: smartctl needs admin commands on /dev/nvme0.
# Total controller wedge kills root fs and this script with it.
# Next boot catches it as prev_end=unclean.

let
  nvmeWatch = pkgs.writeShellApplication {
    name = "nvme-watch";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      jq
      ripgrep
      smartmontools
      systemd
    ];
    text = ''
      log=/var/log/nvme-watch.log
      seen=/var/lib/nvme-watch/boot-id
      pci=/sys/bus/pci/devices/0000:02:00.0
      boot=$(cut -c1-8 /proc/sys/kernel/random/boot_id)
      errors_pattern='controller is down|reset controller|I/O Error'
      alert=0

      if [ "$(cat /sys/class/power_supply/ADP0/online)" = 1 ]; then power=ac; else power=battery; fi
      l1_1=$(cat "$pci/link/l1_1_aspm")
      l1_2=$(cat "$pci/link/l1_2_aspm")
      link="$(cut -d' ' -f1 "$pci/current_link_speed")GT/s-x$(cat "$pci/current_link_width")"
      state=$(cat /sys/class/nvme/nvme0/state)
      boot_errors=$(journalctl -k -b 0 -o cat --no-pager | rg -c "$errors_pattern" || echo 0)

      smart=$(smartctl -j -A -H /dev/nvme0 || true)
      crit=$(jq -r '.nvme_smart_health_information_log.critical_warning' <<<"$smart")
      media=$(jq -r '.nvme_smart_health_information_log.media_errors' <<<"$smart")
      errlog=$(jq -r '.nvme_smart_health_information_log.num_err_log_entries' <<<"$smart")
      unsafe=$(jq -r '.nvme_smart_health_information_log.unsafe_shutdowns' <<<"$smart")
      temp=$(jq -r '.temperature.current' <<<"$smart")

      line="boot=$boot up=$(awk '{printf "%dmin", $1/60}' /proc/uptime) power=$power"
      line+=" aspm_l1_1=$l1_1 aspm_l1_2=$l1_2 link=$link state=$state temp=''${temp}C"
      line+=" nvme_errors_this_boot=$boot_errors smart_crit=$crit media_errors=$media errlog=$errlog unsafe_shutdowns=$unsafe"

      if [ "$(cat "$seen" 2>/dev/null)" != "$boot" ]; then
        # Clean shutdown ends journal with "Journal stopped".
        if [ "$(journalctl -b -1 -o cat -n 1 --no-pager)" = "Journal stopped" ]; then prev_end=clean; else prev_end=unclean; fi
        prev_errors=$(journalctl -k -b -1 -o cat --no-pager | rg -c "$errors_pattern" || echo 0)
        line+=" new_boot prev_end=$prev_end prev_nvme_errors=$prev_errors"
        [ "$prev_end" = clean ] && [ "$prev_errors" = 0 ] || alert=1
        echo "$boot" >"$seen"
      fi

      [ "$l1_1$l1_2" = 00 ] && [ "$link" = 16.0GT/s-x4 ] && [ "$state" = live ] || alert=1
      [ "$boot_errors" = 0 ] && [ "$crit" = 0 ] && [ "$media" = 0 ] && [ "$errlog" = 0 ] || alert=1

      if [ "$alert" = 1 ]; then status=ALERT; else status=ok; fi
      echo "$(date -Is) $status $line" >>"$log"
    '';
  };
in
{
  systemd.services.nvme-watch = {
    description = "Log NVMe controller health";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${nvmeWatch}/bin/nvme-watch";
      StateDirectory = "nvme-watch";
    };
  };

  systemd.timers.nvme-watch = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "1h";
    };
  };
}

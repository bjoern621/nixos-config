{ pkgs, ... }:

let
  brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
  # Marker tells resume that idle dimmed panel.
  # Without it, resume on AC would restore stale saved brightness.
  dimmedMarker = "$XDG_RUNTIME_DIR/hypridle-backlight-dimmed";

  # Battery alone: docked, panel power counts for nothing.
  dimBacklightOnBattery = pkgs.writeShellScript "hypridle-dim-backlight" ''
    [ "$(cat /sys/class/power_supply/ADP0/online)" = 0 ] || exit 0
    ${brightnessctl} --save set 0
    touch "${dimmedMarker}"
  '';
  restoreBacklight = pkgs.writeShellScript "hypridle-restore-backlight" ''
    [ -e "${dimmedMarker}" ] || exit 0
    ${brightnessctl} --restore
    rm "${dimmedMarker}"
  '';
in
{
  # Lock the session before the machine sleeps (suspend/hibernate), so resume
  # requires a password. logind triggers hibernate on lid close
  # (HandleLidSwitch=hibernate in modules/hibernate.nix); hypridle hooks the
  # pre-sleep signal and engages the resident Quickshell session lock
  # (config/lock, run as the quickshell-lock service from quickshell/session-lock.nix).
  #
  # No DPMS commands here on purpose: `dpms off` is a known Hyprland crash
  # trigger on AMD GPUs, and this machine is AMD.
  services.hypridle = {
    enable = true;
    settings.general = {
      # Manual lock path: loginctl lock-session (Super+L) emits the Lock signal,
      # which hypridle turns into quickshell-lock. quickshell-lock is an IPC call
      # to the resident lock instance, so it is idempotent and never stacks.
      lock_cmd = "quickshell-lock";
      # Lock synchronously before sleep. hypridle runs this while holding its
      # delay inhibitor, so the lock engages before the freeze. Calling
      # quickshell-lock directly (not loginctl lock-session) keeps it inside that
      # window; routing through the async Lock signal would race the freeze.
      before_sleep_cmd = "quickshell-lock";
    };
    settings.listener = [
      {
        timeout = 300;
        on-timeout = "${dimBacklightOnBattery}";
        on-resume = "${restoreBacklight}";
      }
    ];
  };
}

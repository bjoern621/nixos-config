{ ... }:

{
  # Lock the session before the machine sleeps (suspend/hibernate), so resume
  # requires a password. logind triggers hibernate on lid close
  # (HandleLidSwitch=hibernate in modules/hibernate.nix); hypridle hooks the
  # pre-sleep signal and engages the resident Quickshell session lock
  # (config/lock, run as the quickshell-lock service from quickshell.nix).
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
  };
}

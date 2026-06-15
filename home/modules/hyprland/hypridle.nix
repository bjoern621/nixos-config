{ ... }:

{
  # Lock the session before the machine sleeps (suspend/hibernate), so resume
  # requires a password. logind triggers hibernate on lid close
  # (HandleLidSwitch=hibernate in modules/hibernate.nix); hypridle hooks the
  # pre-sleep signal and locks via the Quickshell session lock (config/lock,
  # launched by quickshell-lock from quickshell.nix).
  #
  # No DPMS commands here on purpose: `dpms off` is a known Hyprland crash
  # trigger on AMD GPUs, and this machine is AMD.
  services.hypridle = {
    enable = true;
    settings.general = {
      # Start the Quickshell lock on a lock-session request. The launcher is
      # single-instance, so a repeated signal never stacks a second lock.
      lock_cmd = "quickshell-lock";
      # Lock before sleep. loginctl emits the Lock signal that runs lock_cmd.
      before_sleep_cmd = "loginctl lock-session";
    };
  };
}

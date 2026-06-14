{ ... }:

{
  # Lock the session before the machine sleeps (suspend/hibernate), so resume
  # requires a password. logind triggers hibernate on lid close
  # (HandleLidSwitch=hibernate in modules/hibernate.nix); hypridle hooks the
  # pre-sleep signal and locks via hyprlock (configured in hyprlock.nix).
  #
  # No DPMS commands here on purpose: `dpms off` is a known Hyprland crash
  # trigger on AMD GPUs, and this machine is AMD.
  services.hypridle = {
    enable = true;
    settings.general = {
      # Start hyprlock on a lock-session request; never spawn a second instance.
      lock_cmd = "pidof hyprlock || hyprlock";
      # Lock before sleep. loginctl emits the Lock signal that runs lock_cmd.
      before_sleep_cmd = "loginctl lock-session";
    };
  };
}

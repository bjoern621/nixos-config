{ ... }:

{
  # SUPER key alone toggles the Quickshell app launcher (bindr = bind on key release)
  # The launcher uses IPC to toggle visibility within the already-running quickshell process.
  # Apps are launched via 'uwsm app --' for proper systemd unit management.
  # See: https://github.com/Vladimir-csp/uwsm#3-applications-and-slices
  wayland.windowManager.hyprland.settings.bind = [
    "SUPER, Super_L, exec, qs ipc call launcher toggle"
  ];
}

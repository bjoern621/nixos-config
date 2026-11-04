{
  config,
  pkgs,
  ...
}:

let
  qsWrapped = config.quickshell.package;

  lockShell = "${config.home.homeDirectory}/.config/quickshell-lock/shell.qml";

  # Session-lock trigger. Engages the lock on the resident quickshell-lock
  # instance (systemd user service below) over IPC, rather than spawning a fresh
  # Quickshell. The resident instance is already Wayland-connected, so locking is
  # an instant state flip; cold-spawning during the suspend/hibernate window used
  # to race the freeze and die on resume. Idempotent: the IPC handler ignores a
  # lock call when already locked, so repeated lock-session signals do not stack.
  quickshellLock = pkgs.writeShellScriptBin "quickshell-lock" ''
    exec ${qsWrapped}/bin/quickshell ipc -p "${lockShell}" call lock lock
  '';
in

{
  # System half: modules/quickshell-lock.nix.
  imports = [ ../hyprland/hypridle.nix ];

  quickshell.powerActions = [ "lock" ];

  home.packages = [ quickshellLock ]; # quickshell-lock: launches the session lock (config/lock)

  # Separate config tree for the session lock, so it runs as its own Quickshell
  # process (launched by quickshell-lock) instead of inside the bar instance.
  xdg.configFile."quickshell-lock".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/git/nixos-config/home/modules/quickshell/config/lock";

  # Resident session-lock instance. Runs the lock config (config/lock) as its own
  # long-lived Quickshell process, separate from the bar so a bar reload or crash
  # cannot affect the lock and vice versa. It sits idle (locked = false, no
  # surfaces) until the quickshell-lock command flips it via IPC.
  #
  # Restart=on-failure recovers an idle crash so the lock is always available. A
  # crash while locked is held by the compositor (the session stays locked, as
  # with any session-lock client), so a restart cannot bypass it.
  systemd.user.services.quickshell-lock = {
    Unit = {
      Description = "Quickshell session lock (resident)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${qsWrapped}/bin/quickshell -p ${lockShell}";
      Restart = "on-failure";
      RestartSec = 1;
      Environment = [ "QT_QPA_PLATFORMTHEME=gtk3" ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}

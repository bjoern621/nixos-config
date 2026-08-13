{ pkgs, ... }:

# User-session half of USB device authorization. System half: modules/usbguard.nix.
#
# Daemon policy stays strict. Enforcement is narrowed to the lock screen by holding
# a catch-all rule in the daemon while session is unlocked and dropping it on lock.
# Every rule attribute is optional, so bare `allow` matches every device.
#
# Rule is temporary (-t), never written to rules.conf.
# Daemon restart therefore lands in strict state, not permissive.
#
# Two events drop it mid-session, both leaving an unlocked session policed:
# usbguard restart (any rebuild touching it), and any permanent policy write
# (allow-device -p, append-rule without -t), which rebuilds the rule set from file.
# Recover with `systemctl --user restart usbguard-session-policy`.
#
# Two boundaries, two triggers:
#   session start/end - unit below, bound to graphical-session.target.
#   lock/unlock       - WlSessionLock.onLockedChanged in
#                       home/modules/quickshell/config/lock/shell.qml.
let
  # Label is the handle for finding the rule again. Rule ids are assigned by the
  # daemon, so they cannot be hardcoded.
  label = "session-unlocked";

  # Talks to daemon over IPC as the invoking user, which needs the user in
  # services.usbguard.IPCAllowedUsers.
  sessionPolicy = pkgs.writeShellScriptBin "usbguard-session-policy" ''
    set -eu

    usbguard=${pkgs.usbguard}/bin/usbguard

    case "''${1-}" in
      unlocked)
        # Idempotent: relock/reunlock and unit restarts must not stack rules.
        case "$("$usbguard" list-rules)" in
          *'label "${label}"'*) ;;
          *) "$usbguard" append-rule -t 'allow label "${label}"' >/dev/null ;;
        esac
        ;;
      locked)
        "$usbguard" list-rules | while IFS=: read -r id rest; do
          case "$rest" in
            *'label "${label}"'*) "$usbguard" remove-rule "$id" ;;
          esac
        done
        ;;
      *)
        echo "usage: usbguard-session-policy locked|unlocked" >&2
        exit 1
        ;;
    esac
  '';
in
{
  # Also puts the command on the lock process PATH, which is where the QML hook
  # resolves it from.
  home.packages = [ sessionPolicy ];

  # Session lifetime is the outer bracket: no graphical session means the greeter,
  # which gets the same strict policy as the lock screen.
  systemd.user.services.usbguard-session-policy = {
    Unit = {
      Description = "Relax USBGuard hotplug policy while the session is up";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${sessionPolicy}/bin/usbguard-session-policy unlocked";
      ExecStop = "${sessionPolicy}/bin/usbguard-session-policy locked";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}

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
# usbguard restart (any rebuild touching it), and allow-device -p.
# allow-device -p upserts into the one rule matching the device, catch-all included:
# lone match overwrites catch-all, two matches fail with "multiple matching rules".
# Recover with `systemctl --user restart usbguard-session-policy`.
#
# Two boundaries, two triggers:
#   session start/end - unit below, bound to graphical-session.target.
#   lock/unlock       - applyUsbPolicy in
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
        # --no-block: prompt waits on clicks, lock process must not.
        ${pkgs.systemd}/bin/systemctl --user start --no-block usbguard-blocked-prompt.service
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

  # Unlocked session allows every device.
  # Blocks land while locked or before login, and session start and unlock both run this.
  # One notification with buttons per blocked device.
  # usbguard-notifier misses blocks from before login,
  # and its Allow button holds a pointer into an exited thread.
  blockedPrompt = pkgs.writeShellScriptBin "usbguard-blocked-prompt" ''
    set -u

    usbguard=${pkgs.usbguard}/bin/usbguard

    # Quickshell owns notification name, may still be starting at login.
    for _ in $(seq 30); do
      ${pkgs.systemd}/bin/busctl --user status org.freedesktop.Notifications >/dev/null 2>&1 && break
      sleep 1
    done

    prompt() {
      choice=$(${pkgs.libnotify}/bin/notify-send \
        --app-name=USBGuard \
        --urgency=critical \
        --action=once=Erlauben \
        --action=always="Immer erlauben" \
        "USB-Gerät blockiert" \
        "$2 ($3) ist angeschlossen, aber blockiert. „Erlauben“ gilt bis zum Abziehen, „Immer erlauben“ dauerhaft.")
      case "$choice" in
        once) "$usbguard" allow-device "$1" ;;
        always)
          # Catch-all matches every device.
          # Upsert needs device's own rule as sole match.
          ${sessionPolicy}/bin/usbguard-session-policy locked
          "$usbguard" allow-device -p "$1"
          ${sessionPolicy}/bin/usbguard-session-policy unlocked
          ;;
      esac
    }

    # Line: 67: block id 36bc:0001 serial "…" name "Fractal Scape Dongle" hash …
    "$usbguard" list-devices --blocked | {
      while IFS= read -r line; do
        name=$(printf '%s\n' "$line" | ${pkgs.gnused}/bin/sed -n 's/.* name "\([^"]*\)".*/\1/p')
        usbId=$(printf '%s\n' "$line" | ${pkgs.gnused}/bin/sed -n 's/.* id \([0-9a-f:]*\) .*/\1/p')
        prompt "''${line%%:*}" "''${name:-Unbekanntes Gerät}" "$usbId" &
      done
      # Unit stays active until every prompt closes, so a repeat unlock adds no duplicates.
      wait
    }
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

  # Started by usbguard-session-policy unlocked.
  # Type=exec: start on active unit stays no-op.
  systemd.user.services.usbguard-blocked-prompt = {
    Unit = {
      Description = "Offer to allow USB devices USBGuard blocked";
      PartOf = [ "graphical-session.target" ];
      After = [ "quickshell.service" ];
    };
    Service = {
      Type = "exec";
      ExecStart = "${blockedPrompt}/bin/usbguard-blocked-prompt";
    };
  };

  systemd.user.services.usbguard-notifier = {
    Unit = {
      Description = "USBGuard device notifications";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      # Default gives up after 3 IPC attempts, e.g. across usbguard restart.
      # --wait retries forever.
      ExecStart = "${pkgs.usbguard-notifier}/bin/usbguard-notifier --wait";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}

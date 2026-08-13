{ config, lib, ... }:

# USB device authorization.
# Daemon deauthorizes any hotplugged device matching no rule, so keyboard emulator
# plugged into locked machine never binds.
#
# Rule set is machine-local mutable state, not repo state: rules carry per-device
# serial + descriptor hash. Seeded on first daemon start from whatever is connected,
# so enabling rebuild should run with usual peripherals attached.
#
# Add device later:
#   usbguard list-devices --blocked
#   usbguard allow-device -p <id>
# -p persists rule. Without it authorization dies on next daemon restart.
#
# YubiKeys (modules/fido2-auth.nix) need same one-time allow-device -p, unless
# connected during seeding. Blocked key makes SDDM passkey path find no device and
# fall through; password and face still work.
{
  services.usbguard = {
    enable = true;

    # block deauthorizes but keeps device listed, which allow-device needs.
    # reject unbinds entirely, leaving nothing to authorize later.
    implicitPolicyTarget = "block";

    # Devices present at daemon start keep kernel authorization regardless of rules.
    # Bad or missing seed then costs nothing: no boot can strand the machine without
    # keyboard, camera or dock. Cost: device plugged into powered-off machine is
    # authorized by enumeration before daemon runs. Closing that needs
    # usbcore.authorized_default=0 plus presentDevicePolicy = "apply-policy".
    presentDevicePolicy = "keep";

    # Load-bearing setting: hotplug after daemon start is matched against rule set,
    # unknown device falls to implicitPolicyTarget.
    insertedDevicePolicy = "apply-policy";

    # Match on descriptors + serial, not port. Known device works in any dock socket.
    deviceRulesWithPort = false;

    # CLI reaches daemon over IPC socket. Without this every allow-device needs root.
    IPCAllowedUsers = [
      "root"
      "bjoern"
    ];
  };

  # Upstream preStart only touches rules.conf into existence. Empty rule set plus
  # implicit block target blocks every later hotplug. Seed from connected devices.
  # Guarded on empty file, so rules added by allow-device -p survive.
  # Temp file keeps failed generate-policy from truncating rule set to nothing.
  systemd.services.usbguard.preStart = lib.mkAfter ''
    if [ ! -s ${config.services.usbguard.ruleFile} ]; then
      ${config.services.usbguard.package}/bin/usbguard generate-policy \
        > ${config.services.usbguard.ruleFile}.seed
      if [ -s ${config.services.usbguard.ruleFile}.seed ]; then
        mv ${config.services.usbguard.ruleFile}.seed ${config.services.usbguard.ruleFile}
      else
        rm -f ${config.services.usbguard.ruleFile}.seed
      fi
    fi
  '';
}

{ config, lib, ... }:

# TPM2 unlock for LUKS devices, bound to Secure Boot state (PCR 7).
# The TPM releases the key while Secure Boot runs with the enrolled keys.
#
# One-time enrolment after the first rebuild, per device:
#   sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-uuid/<uuid>
#
# Re-enrolment after a key rotation:
#   sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/disk/by-uuid/<uuid>
#   sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-uuid/<uuid>

let
  cfg = config.boot.initrd.luks.tpm2Unlock;
in
{
  options.boot.initrd.luks.tpm2Unlock.devices = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Names under boot.initrd.luks.devices the TPM unlocks.";
  };

  config = lib.mkIf (cfg.devices != [ ]) {
    boot.initrd.systemd.enable = true;

    boot.initrd.luks.devices = lib.genAttrs cfg.devices (_: {
      crypttabExtraOpts = [
        "tpm2-device=auto"
        "tpm2-pcrs=7"
      ];
    });
  };
}

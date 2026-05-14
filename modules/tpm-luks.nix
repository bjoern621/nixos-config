{ ... }:

# TPM2-based automatic LUKS unlock, bound to Secure Boot state (PCR 7).
# The TPM only releases the key when Secure Boot is active with enrolled keys.
#
# One-time setup after first rebuild:
#   sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-uuid/d3e9b59e-a5a9-4a07-b5b2-405fca67f400
#
# If you ever need to re-enroll (e.g. after key rotation):
#   sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/disk/by-uuid/d3e9b59e-a5a9-4a07-b5b2-405fca67f400
#   sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-uuid/d3e9b59e-a5a9-4a07-b5b2-405fca67f400
{
  boot.initrd.systemd.enable = true;

  boot.initrd.luks.devices."luks-d3e9b59e-a5a9-4a07-b5b2-405fca67f400" = {
    crypttabExtraOpts = [
      "tpm2-device=auto"
      "tpm2-pcrs=7"
    ];
  };
}

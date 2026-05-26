# Keyring Auto-Unlock After Face Login

## Problem

Password login auto-unlocks the GNOME Keyring via `pam_gnome_keyring` (auth
phase). Face login (Howdy) has no password at auth time, so the keyring stays
locked and apps (Seahorse, VSCode Settings Sync, browsers, …) prompt for it
later.

## Solution

Seal the login password inside the TPM. After a successful face login a PAM
session helper ([modules/display-manager.nix](../modules/display-manager.nix))
decrypts it and pipes it to `gnome-keyring-daemon --unlock`.

Files live in `${XDG_DATA_HOME:-~/.local/share}/sddm/keyring-tpm/`:

```
~/.local/share/sddm/keyring-tpm/
├── key.pub          # TPM key public part
├── key.priv         # TPM key private part (sealed to this TPM)
└── password.enc     # Login password encrypted with that key
```

Missing files → helper logs a reason and exits 0 (never blocks login).

## One-Time Setup

`tss` group membership is required (configured for `bjoern` in
[modules/display-manager.nix](../modules/display-manager.nix)). Verify:
`id -nG | tr ' ' '\n' | grep tss`.

Run as your normal user (NOT root). Two phases so a failed seal doesn't wipe
contexts you'd need to retry.

**Phase 1: generate keys and seal the password.** Wipes the dir first to stay
idempotent across retries. Type the CURRENT login password at the prompt: no
trailing newline, no spaces. (No shell comments inside the block so it pastes
into bash and zsh alike.)

```sh
TPM_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/sddm/keyring-tpm"
mkdir -p "$TPM_DIR" && rm -f "$TPM_DIR"/{primary.ctx,key.ctx,key.pub,key.priv,password.enc}
cd "$TPM_DIR"
tpm2_createprimary -Q -c primary.ctx
tpm2_create -Q -C primary.ctx -G aes128 -u key.pub -r key.priv
tpm2_load   -Q -C primary.ctx -u key.pub -r key.priv -c key.ctx
printf 'login password: '
read -rs PW; echo
printf '%s' "$PW" | tpm2_encryptdecrypt -Q -c key.ctx -o password.enc
unset PW
```

Verify the seal before proceeding:

```sh
[ -s "$TPM_DIR/password.enc" ] && echo OK || echo "FAIL: password.enc missing or empty"
```

If it printed `FAIL`, do NOT continue. Re-run Phase 1.

**Phase 2: drop transient contexts and lock down permissions:**

```sh
rm -f "$TPM_DIR"/primary.ctx "$TPM_DIR"/key.ctx
chmod 700 "$TPM_DIR"
chmod 600 "$TPM_DIR"/*
```

After Phase 2, `ls "$TPM_DIR"` should show exactly `key.pub`, `key.priv`,
`password.enc`.

## Verify

After the next face login:

```bash
journalctl -b -t sddm-keyring-tpm
```

Expected on success:

```
sddm-keyring-tpm: OK: keyring unlocked via TPM-sealed password
```

Failures are tagged `FAIL: <reason>` and explain which step broke (missing
files, TPM access denied, password mismatch, etc.).

## Re-Seal After Password Change

The blob stores a fixed string. After `passwd`, re-run the
[One-Time Setup](#one-time-setup); otherwise decrypt succeeds but
`gnome-keyring-daemon --unlock` rejects the stale password.

## Security Notes

- Key is sealed to **this TPM**; the directory is useless if copied elsewhere.
- No PCR policy bound: any local process running as your user with TPM access
  can decrypt. LUKS is the primary defense at rest; mode 600 prevents other
  local users from reading.
- For stronger guarantees, bind to PCRs (e.g. PCR 7 for Secure Boot) via
  `tpm2_createpolicy` + `tpm2_create -L policy.dat`. Not set up here.

## Troubleshooting

| Symptom (journal)                                 | Cause / Fix                                                                     |
| ------------------------------------------------- | ------------------------------------------------------------------------------- |
| `keyring-tpm missing` / `key.pub missing`         | Setup never ran; follow [One-Time Setup](#one-time-setup).                      |
| `tpm2_createprimary: ... permission denied`       | Not in `tss` group, or `/dev/tpmrm0` missing. Reboot after rebuild, check `id`. |
| `tpm2_load: ...`                                  | Key files don't match this TPM (e.g. firmware reset, restored backup). Re-seal. |
| `gnome-keyring-daemon --unlock: ...`              | Stored password no longer matches login password. Re-seal.                      |
| No `sddm-keyring-tpm` lines at all in the journal | PAM session hook didn't run; check `journalctl -b _COMM=sddm-helper`.           |

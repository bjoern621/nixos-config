# Keyring Auto-Unlock After Face Login

## Problem

When you log in with a typed password, `pam_gnome_keyring` (auth phase) uses that
password to unlock your default GNOME Keyring. When you log in with **Howdy
(face recognition)**, no password is available at the auth phase, so the keyring
stays locked and apps (Seahorse, VSCode Settings Sync, browsers, etc.) prompt
for it later.

## Solution

We seal your login password inside the TPM. After a successful face login, a
PAM session helper ([modules/display-manager.nix](../modules/display-manager.nix))
decrypts it via the TPM and pipes it to `gnome-keyring-daemon --unlock`.

The encrypted blob and TPM key handles live in `~/.tpm/`:

```
~/.tpm/
├── key.pub          # TPM key public part
├── key.priv         # TPM key private part (sealed to this TPM)
└── password.enc     # Login password encrypted with that key
```

Without these files, the helper logs a reason to the journal and exits silently
(login is never blocked).

## One-Time Setup

Run as your normal user (NOT root):

```bash
mkdir -p ~/.tpm && cd ~/.tpm

tpm2_createprimary -Q -c primary.ctx
tpm2_create -Q -C primary.ctx -G aes128 -u key.pub -r key.priv
tpm2_load   -Q -C primary.ctx -u key.pub -r key.priv -c key.ctx

# Seal your CURRENT login password (no trailing newline, no spaces).
read -rs -p "login password: " PW; echo
printf '%s' "$PW" | tpm2_encryptdecrypt -Q -c key.ctx -o password.enc
unset PW

rm -f primary.ctx key.ctx
chmod 700 ~/.tpm
chmod 600 ~/.tpm/*
```

Membership in the `tss` group is required and already configured for `bjoern`
in [modules/display-manager.nix](../modules/display-manager.nix). Verify with
`id -nG | tr ' ' '\n' | grep tss`.

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

The blob stores a fixed string. Whenever you change your Linux login password
(`passwd`), repeat the [setup steps](#one-time-setup); otherwise the helper
will succeed at decrypting but `gnome-keyring-daemon --unlock` will reject the
stale password.

## Security Notes

- The key is sealed to **this TPM**: copying `~/.tpm/` to another machine is
  useless.
- No PCR policy is bound, so any local process running as your user with TPM
  access can decrypt the blob. Disk encryption (LUKS) is the primary defense at
  rest; mode 600 on the files prevents other local users from reading them.
- For stronger guarantees, bind to PCRs (e.g. PCR 7 for Secure Boot state)
  using `tpm2_createpolicy` + `tpm2_create -L policy.dat`. Not currently set
  up in this repo.

## Troubleshooting

| Symptom (journal)                                | Cause / Fix                                                                |
| ------------------------------------------------ | -------------------------------------------------------------------------- |
| `~/.tpm missing`                                 | Setup never ran; follow [One-Time Setup](#one-time-setup).                 |
| `tpm2_createprimary: ... permission denied`      | Not in `tss` group, or `/dev/tpmrm0` missing. Reboot after rebuild, check `id`. |
| `tpm2_load: ...`                                 | Key files don't match this TPM (e.g. firmware reset, restored backup). Re-seal. |
| `gnome-keyring-daemon --unlock: ...`             | Stored password no longer matches login password. Re-seal.                  |
| No `sddm-keyring-tpm` lines at all in the journal | PAM session hook didn't run; check `journalctl -b _COMM=sddm-helper`.      |

# Installation

This guide installs a host in `hosts/` onto a machine that boots the NixOS installer: the desktops `nixos` and `fractal`, and the local servers `homelab` and `vmk3s`.
It has two parts: the [general steps](#general-steps), which every such host takes, and the [module sections](#module-sections), which apply only when the host imports that module or sets the option they name.

The remote servers and the Pi never boot an installer and have their own guides:

| Host | Route |
| --- | --- |
| `pi-4b-hh` | Flashed SD card image, see [Raspberry Pi SD Card Hosts](../README.md#raspberry-pi-sd-card-hosts). |
| `hetzner-hel1`, `netcup-g12` | Cloud install over the network, see [Installing a cloud host](k3s-cluster.md#installing-a-cloud-host). |

## Before you start

Pick the host profile now, because the installer asks for the username and the profile fixes it:

| Host | User |
| --- | --- |
| `nixos`, `fractal` | `bjoern` |
| `homelab`, `vmk3s` | `ops` |

> [!IMPORTANT]
> Create exactly that user in the installer.
> A different username makes Home Manager build a second home directory, and the clone and every hand-placed file from these steps then sit in the wrong one.

List the modules the host imports, from any checkout or on GitHub:

```bash
grep -o 'modules/[^ ]*\.nix' hosts/<host>/configuration.nix
```

Desktop hosts also get the Home Manager modules in `home/bjoern.nix`; their sections say so.

Read the [module sections](#module-sections) for every module on that list before starting.
Some of them need work before the installer boots, such as the firmware settings for Secure Boot.

Have these at hand:

- A USB stick with the git-crypt key `nixos-config-key`, for desktop hosts.
- Access to Bitwarden, for the admin SSH key and the LUKS passphrase.
- A second machine that holds the admin age key at `~/.config/sops/age/keys.txt`, for hosts that import `modules/sops.nix`.

## General steps

### 1. Install NixOS with the graphical installer

Download the **Graphical ISO image** from <https://nixos.org/download/> and boot it.
Use it rather than the minimal ISO.
The graphical installer partitions, encrypts and formats the disk, creates the user and joins Wi-Fi from a GUI, and its live session has a browser for this guide and for Bitwarden.
The minimal ISO leaves all of that to commands typed by hand.

In the installer:

1. **Location and keyboard:** Germany, German (`de`) layout, matching `console.keyMap`.
2. **Users:** the username from [Before you start](#before-you-start).
   Choose the password you will log in with.
   Hosts that unlock the keyring from the TPM seal this password later.
3. **Desktop:** No desktop.
   The flake configuration brings Hyprland and SDDM itself.
4. **Partitions:** Erase disk.
   Tick **Encrypt system** on hosts that import `modules/tpm-luks.nix`, and store the passphrase in Bitwarden.
   It stays the fallback when the TPM refuses to unlock.
   Pick **No swap**: `modules/hibernate.nix` creates its own swap file, and the other hosts run without disk swap.

Reboot into the installed system when it finishes.

### 2. Get the tools for the first build

The installed system has neither git nor git-crypt, and flakes are not enabled yet, so `nix shell` does not work.
Open a shell that has both:

```bash
nix-shell -p git git-crypt
```

Run the remaining steps up to the first build inside it.

### 3. Clone the repository

```bash
git clone https://github.com/bjoern621/nixos-config.git ~/git/nixos-config
```

The checkout stays here.
Every `sysconf-*` command reads `sysconf.configPath`, which each host derives from `sysconf.user` as that account's `~/git/nixos-config`.

### 4. Pick the host

```bash
ls ~/git/nixos-config/hosts
export HOST=<host>
```

### 5. Copy the hardware configuration

The repository holds a placeholder at `hosts/$HOST/hardware-configuration.nix`.
Copy the machine's real file over it and tell git to ignore the change:

```bash
sudo cp /etc/nixos/hardware-configuration.nix ~/git/nixos-config/hosts/$HOST/hardware-configuration.nix
git -C ~/git/nixos-config update-index --skip-worktree hosts/$HOST/hardware-configuration.nix
```

The real file never goes into git.
[Hardware configuration](../README.md#hardware-configuration) in the README explains why, and how `sysconf-reload` repeats this copy before every later build.

### 6. Unlock the git-crypt files

Desktop hosts only.
The Icons8 SVGs of Quickshell and the SDDM theme sit encrypted in the repository.
A build from a locked clone deploys them as ciphertext, which Quickshell logs as `Unsupported image format`.

```bash
install -d -m 700 ~/.config/git-crypt
install -m 600 /run/media/$USER/<stick>/nixos-config-key ~/.config/git-crypt/
git -C ~/git/nixos-config crypt unlock ~/.config/git-crypt/nixos-config-key
```

The unlock installs git filters that call `git-crypt`, and git fails on them until the first build installs it.
Until then, run git commands inside the `nix-shell` from step 2.

### 7. Work through the pre-build module steps

Go through the [module sections](#module-sections) for every module the host imports and run each part marked **Before the first build**.
Skipping one fails the build or its activation.

### 8. Build and reboot

Install the configuration as the next boot entry and reboot into it:

```bash
sudo NIXOS_REBUILD_NO_SYSTEMD_RUN=1 nixos-rebuild boot --flake ~/git/nixos-config/hosts/$HOST
sudo reboot
```

`boot` rather than `switch`, because the first build swaps the boot loader, the display manager and the kernel, none of which a live switch can take over cleanly.
`nixos-rebuild` would hand the build to `systemd-run --output=cat`, and the `systemd-run` of a freshly installed system may be older and reject that option.

The first build takes long.
The extra binary caches the configuration lists take effect only once it is active, so this build may compile parts of the Hyprland stack from source.

### 9. Place the admin SSH key

Hosts `nixos` and `fractal` only.
Copy the admin SSH key from Bitwarden.
The servers list its public half in `modules/admin-ssh-keys.nix`.

Run the commands, paste the private key, press Enter after its last line and finish with Ctrl+D.
OpenSSH rejects the file without its final newline.

```bash
install -d -m 700 ~/.ssh
install -m 600 /dev/null ~/.ssh/id_ed25519
cat > ~/.ssh/id_ed25519
```

### 10. Work through the post-boot module steps

Go through the [module sections](#module-sections) again and run each part marked **After the first boot**.

### 11. Check the result

```bash
sysconf-reload
git -C ~/git/nixos-config status
```

`sysconf-reload` finishes without changes, and `git status` shows a clean tree.
From now on, rebuild with the `sysconf-*` commands only (`sysconf-help` lists them).

## Module sections

Each section names the module it belongs to and when its steps run.
A host that does not import the module skips the section.

### Secure Boot

Module: `modules/secureboot.nix` (lanzaboote).

**Before installing:** the firmware must be in setup mode, with no platform key, so it boots the unsigned installer and the first system.
In the firmware settings, set Secure Boot Mode to Custom and clear the Secure Boot keys.
On Standard mode the firmware reinstalls its factory keys at the next boot.
The menu path differs by vendor; on ASUS boards it is Boot, Secure Boot, Key Management.

**After the first boot:** nothing to do by hand.
The first boot generates the keys under `/var/lib/sbctl`, writes them to the ESP and reboots, and systemd-boot enrolls them on the boot after.
Hosts that set `boot.lanzaboote.autoEnrollKeys.includeMicrosoftKeys = true` enroll the Microsoft keys too, which a Windows dual boot and some GPU option ROMs need.

Check:

```bash
bootctl status | grep -i 'secure boot'   # enabled (user)
sudo sbctl status
```

### TPM unlock of the encrypted root

Module: `modules/tpm-luks.nix`.
Needs Secure Boot, because the TPM key is bound to PCR 7.

**Before the first build:** the host's `configuration.nix` names the LUKS device the TPM unlocks.
The graphical installer calls it `luks-<uuid>`, and the copied hardware file holds the full name:

```bash
grep -o 'luks-[0-9a-f-]*' ~/git/nixos-config/hosts/$HOST/hardware-configuration.nix
```

Set it in `hosts/$HOST/configuration.nix` and commit that change:

```nix
boot.initrd.luks.tpm2Unlock.devices = [ "luks-<uuid>" ];
```

**After the first boot:** once `bootctl status` reports Secure Boot as enabled, enroll the TPM.
Enrolling earlier binds the key to a PCR 7 value that changes when Secure Boot turns on, and the next boot asks for the passphrase again.

```bash
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-uuid/<uuid>
```

The next boot unlocks the disk without a prompt.
After a Secure Boot key rotation, re-enroll:

```bash
sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/disk/by-uuid/<uuid>
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-uuid/<uuid>
```

### sops secrets

Module: `modules/sops.nix`, and every module that declares `sops.secrets` (`attic-push.nix`, `wireguard-wstunnel.nix`, the k3s modules).

**Before the first build:** activation fails when the host cannot decrypt a secret it declares, so the host's age key must be a recipient before the build.
Create the key on the new machine and print its public half:

```bash
sudo install -d -m 700 /var/lib/sops-nix
sudo nix-shell -p age --run 'age-keygen -o /var/lib/sops-nix/key.txt'
sudo chmod 600 /var/lib/sops-nix/key.txt
sudo nix-shell -p age --run 'age-keygen -y /var/lib/sops-nix/key.txt'
```

On the machine with the admin age key:

1. Add the printed public key to `.sops.yaml` as `host_<host>`, or replace the old one on a reinstall.
2. List it in each creation rule whose secrets the host reads.
3. Re-encrypt, commit and push:

    ```bash
    sops updatekeys secrets/*.yaml
    ```

Then pull on the new machine.
Adding or changing a secret value follows the steps in [CLAUDE.md](../CLAUDE.md#secrets).

### Keyring auto-unlock without a typed password

Modules: `modules/keyring.nix` and `modules/display-manager.nix`, on hosts that log in without typing the password.
That covers face login (`modules/howdy.nix`) and SDDM autologin (`services.displayManager.autoLogin`).

A typed password unlocks the GNOME Keyring at login.
Face login and autologin supply none, so apps would prompt for the keyring later.
A PAM session hook unlocks it with the login password sealed in the TPM.

**After the first boot:**

1. Seal the login password: [docs/keyring-auto-unlock.md](keyring-auto-unlock.md#one-time-setup), phases 1 and 2.
2. Reboot and confirm the hook ran:

    ```bash
    journalctl -b -t sddm-keyring-tpm   # OK: keyring unlocked via TPM-sealed password
    ```

3. Check which keyrings exist:

    ```bash
    ls ~/.local/share/keyrings/
    ```

    The hook unlocks only `login.keyring`, and creates it on the first sealed login.
    An app that stored a secret before that created a separate `Default_Keyring.keyring`, which stays locked.
    At its next unlock prompt, type its password and tick **Automatically unlock this keyring whenever I'm logged in**.
    That stores its password inside the login keyring, so later logins unlock both.
    The prompt offers this option only while an unlocked login keyring exists.

Re-seal after every `passwd`.

### Encrypted games volume

Host option: a `games` entry in `environment.etc.crypttab` with `fileSystems."/games"` (`fractal`).
The volume sits on a partition with partlabel `games`, outside the disk the installer used.
It opens with a key file on the encrypted root, so the boot shows no second prompt.
Both entries carry `nofail`, so a missing volume never blocks the boot.

**After the first boot:** create the key, then the volume in free space on the second disk.
`sgdisk` and `luksFormat` destroy what they target, so check the disk path with `lsblk` first.

```bash
sudo install -d -m 700 /etc/luks
sudo sh -c 'head -c 64 /dev/urandom > /etc/luks/games.key'
sudo chmod 600 /etc/luks/games.key
sudo nix-shell -p gptfdisk --run 'sgdisk --new=0:0:0 --typecode=0:8309 --change-name=0:games /dev/disk/by-id/<disk>'
sudo udevadm settle
sudo cryptsetup luksFormat --key-file /etc/luks/games.key /dev/disk/by-partlabel/games
sudo cryptsetup open --key-file /etc/luks/games.key /dev/disk/by-partlabel/games games
sudo mkfs.ext4 -L games /dev/mapper/games
sudo mount /games
sudo chown $USER:users /games
```

Every later boot opens and mounts it from `crypttab` and `fstab`.
Steam, Heroic, Lutris and Prism Launcher take `/games` as a library or install path in their settings.

### Face login

Module: `modules/howdy.nix`.

**Before the first build:** `services.howdy.settings.video.device_path` names the IR camera as `/dev/video2`.
On other hardware, find the IR node and adjust it:

```bash
nix-shell -p v4l-utils --run 'v4l2-ctl --list-devices'
```

**After the first boot:** calibrate the IR emitter and enroll a face, see [docs/howdy-face-login.md](howdy-face-login.md).
Then set up [keyring auto-unlock](#keyring-auto-unlock-without-a-typed-password).

### FIDO2 security keys

Module: `modules/fido2-auth.nix`.

**After the first boot:** register both YubiKeys.
Insert key 1 and touch it for the first command, then key 2 for the second:

```bash
( pamu2fcfg -u $USER; pamu2fcfg -u $USER -n ) | paste -sd '' - | sudo tee /etc/u2f-mappings
```

The file holds one line, `<user>:<cred-key1>:<cred-key2>`.
On hosts with USBGuard, allow the keys first (next section).

### USBGuard

Module: `modules/usbguard.nix`.

**Before the first build:** plug in the usual peripherals: dock, keyboard, mouse, both YubiKeys.
The daemon seeds its rule set from whatever is connected at its first start.

**After the first boot:** allow each device that was missing during seeding:

```bash
usbguard list-devices --blocked
usbguard allow-device -p <id>
```

`-p` persists the rule; without it the authorization ends at the next daemon restart.

### Hibernate

Module: `modules/hibernate.nix`.

The swap file must exist before its resume offset can be read, so the first install takes two builds.
Copying another machine's `resumeDevice` and `resumeOffset` stalls the boot at `waiting for device`.

**Before the first build:** set only the size in `hosts/$HOST/configuration.nix`:

```nix
system.hibernate = {
  enable = true;
  swapFile.size = 32; # GB, at least the RAM size
};
```

**After the first boot:** read the device and offset, fill them in and rebuild.
[Boot hangs on "waiting for device"](../README.md#boot-hangs-on-waiting-for-device-after-install) in the README has the commands.

### Tailscale

Module: `modules/tailscale-client.nix`.

**After the first boot:** log the machine into the tailnet.
The command prints a login link.

```bash
sudo tailscale up
```

Server hosts that join k3s take a second rebuild after this, see [Adding a node](k3s-cluster.md#adding-a-node).

### Attic binary cache push

Module: `modules/attic-push.nix`.
Needs [sops secrets](#sops-secrets), since the push token lives in `secrets/attic.yaml`.

**After the first boot:** `attic-watch-store` pushes every new local build on its own.
Optionally seed the cache with the store as it stands:

```bash
attic push hh:system $(nix path-info --all)
```

### WireGuard over NetworkManager

Module: `modules/wireguard.nix`.

**After the first boot:** place each config outside the repository, import it and keep it from starting at boot:

```bash
sudo install -m 600 <name>.conf /etc/wireguard/<name>.conf
sudo nmcli connection import type wireguard file /etc/wireguard/<name>.conf
sudo nmcli connection modify <name> connection.autoconnect no
```

### WireGuard over wstunnel

Module: `modules/wireguard-wstunnel.nix`.

Nothing to do by hand.
The client key comes from `secrets/wireguard-client.yaml`, so [sops secrets](#sops-secrets) must be set up.

### OpenVPN

Module: `modules/networkmanager-openvpn.nix`.

**After the first boot:** import the CyberGhost profile:

```bash
nmcli connection import type openvpn file <profile>.ovpn
```

### eduroam

Module: `modules/eduroam.nix`.

**After the first boot:** download the PKCS12 file from <https://www.easyroam.de/>, extract it and create the connection, both as root:

```bash
sudo easyroam_extract <file>.p12
sudo easyroam_nmcli
```

### Calendar

Module: `home/modules/calendar.nix` (all desktop hosts).

**After the first boot:** Evolution Data Server prompts once for the Radicale password and keeps it in the keyring.
To skip the prompt, store it ahead:

```bash
secret-tool store --label=Radicale e-source-uid radicale eds-origin evolution-data-server
```

### Spotify in the Quickshell bar

Module: `home/modules/quickshell/quickshell.nix` (all desktop hosts).

**After the first boot:** store the Spotify app's client ID and secret, then log in through the browser:

```bash
quickshell-spotify setup
quickshell-spotify auth
```

Both land in the keyring, so set up [keyring auto-unlock](#keyring-auto-unlock-without-a-typed-password) first on hosts that need it.

### Paint.NET

Module: `home/modules/paintdotnet.nix` (all desktop hosts).

**After the first boot:** launch WinBoat and finish its Windows installation wizard.
Inside the VM, install Paint.NET from <https://getpaint.net> and add it as a seamless app through WinBoat's app integration.

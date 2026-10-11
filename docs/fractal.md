# fractal

Gaming desktop with Windows 11 and NixOS on separate NVMe disks.
The firmware boot menu picks the disk; neither boot loader knows about the other.

## Disks

| Disk | Holds |
| --- | --- |
| Crucial T700 2 TB | NixOS: ESP and a LUKS root (ext4), as `hosts/fractal/disko.nix` declares. The TPM unlocks the root, bound to Secure Boot state. |
| Samsung 990 PRO 4 TB | Windows on the first 2 TB with its own ESP, then a LUKS ext4 volume mounted at `/games`, partlabel `games`, opened with the key file at `/etc/luks/games.key`. |

The Windows disk never enters `disko.nix`.
disko formats whole disks, and a layout naming the 990 PRO would take Windows with it.

## Installing Windows

Windows comes first, with the T700 out of its M.2 slot.
The Windows installer puts its boot files onto an ESP it finds on any disk, and the T700 would otherwise end up carrying them.

1. Pull the T700 from its slot.
2. Boot the Windows 11 installer and choose the custom installation.
   Delete every partition on the 990 PRO, create one partition of 2 TB and leave the rest unallocated.
   The installer adds its own ESP, MSR and recovery partitions next to it.
3. At the account screen press Shift+F10 and run `start ms-cxh:localonly` to create a local account.
   A local account skips Device Encryption, which would otherwise bind the disk to the TPM and ask for a recovery key after every Secure Boot change.
4. After the first login, confirm that encryption is off and disable it where it is on:

    ```powershell
    # Windows, elevated PowerShell
    manage-bde -status C:
    manage-bde -off C:
    ```

5. Put the T700 back.

## Installing NixOS

The install runs from the laptop over the LAN with nixos-anywhere, as for the cloud hosts in [k3s-cluster.md](k3s-cluster.md).
The bootstrap configuration `fractal-bootstrap` carries the disks, systemd-boot and ssh for root; the full system follows over `sysconf-reload`.

1. In the firmware, clear the Secure Boot keys (Boot, Secure Boot, Key Management).
   With no platform key the firmware sits in setup mode and boots the unsigned bootstrap.
   The full system enrolls its own keys together with the Microsoft ones on its first activation and reboots with Secure Boot on.
2. Boot the NixOS minimal ISO from a USB stick, set a root password with `passwd` and read the address with `ip a`.
3. Read the T700's stable device path on the target and keep the serial:

    ```sh
    ls -l /dev/disk/by-id/ | grep CT2000T700
    ```

4. On the laptop, prepare what the installer carries onto the new root: the sops age key, the games key file and a passphrase for the root volume.

    ```sh
    # laptop, in a scratch directory
    mkdir -p extra/var/lib/sops-nix extra/etc/luks
    nix shell nixpkgs#age --command age-keygen -o extra/var/lib/sops-nix/key.txt
    head -c 64 /dev/urandom > extra/etc/luks/games.key
    chmod 700 extra/etc/luks
    chmod 600 extra/var/lib/sops-nix/key.txt extra/etc/luks/games.key
    printf '%s' '<passphrase>' > cryptroot.key
    ```

    The passphrase stays the fallback for a TPM that refuses to unlock, so it goes into the password manager.

5. Register the host key with sops before the first activation, in the repository:

    ```sh
    nix shell nixpkgs#age --command age-keygen -y extra/var/lib/sops-nix/key.txt
    ```

    Add the printed key to `.sops.yaml` as `host_fractal`, list it in the catch-all rule, then run `sops updatekeys secrets/*.yaml`, commit and push.
    The first activation reads the Attic token out of `secrets/attic.yaml`.

6. Install the bootstrap.
   The flag `--disk main` names the disk disko formats; without it disko stops, since `disko.nix` points at `/dev/null`.

    ```sh
    nixos-anywhere --flake hosts/fractal#fractal-bootstrap --target-host root@<address> \
      --disk main /dev/disk/by-id/nvme-CT2000T700SSD3_<serial> \
      --disk-encryption-keys /tmp/cryptroot.key ./cryptroot.key \
      --extra-files extra \
      --generate-hardware-config nixos-generate-config extra/etc/nixos/hardware-configuration.nix
    ```

    nixos-anywhere generates the hardware file without file systems, which disko already declares.
    A hardware file written by hand on this host takes `nixos-generate-config --no-filesystems` for the same reason.

7. Deploy the full system once the bootstrap is up:

    ```sh
    sysconf-reload fractal --remote root@<address>
    ```

    The activation enrolls the Secure Boot keys and reboots.
    The machine comes back with Secure Boot on and logs `bjoern` straight into Hyprland.

## After the first boot

Each step runs on fractal as root.

1. Enroll the TPM, after Secure Boot is on, since PCR 7 settles only then:

    ```sh
    systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-partlabel/disk-main-root
    ```

2. Create the games volume in the space Windows left unallocated:

    ```sh
    nix shell nixpkgs#gptfdisk --command sgdisk --new=0:0:0 --typecode=0:8309 --change-name=0:games /dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_<serial>
    udevadm settle
    cryptsetup luksFormat --key-file /etc/luks/games.key /dev/disk/by-partlabel/games
    cryptsetup open --key-file /etc/luks/games.key /dev/disk/by-partlabel/games games
    mkfs.ext4 -L games /dev/mapper/games
    mount /games
    chown bjoern:users /games
    ```

    Every later boot opens and mounts it from `crypttab` and `fstab`.

3. Join the tailnet with `tailscale up`, which prints the login link.
4. Put the NixOS entry first in the firmware boot order.
   `sudo reboot-to-windows` starts Windows once and leaves the order alone.
5. Import the CyberGhost profile as on the laptop: `nmcli connection import type openvpn file <profile>.ovpn`.

## Games on NixOS

Steam, Heroic, Lutris and Prism Launcher install into `/games`, which each launcher takes as a library or install path in its settings.
Proton GE sits in Steam's compatibility tool list from the start.
Titles behind a kernel anti-cheat stay on the Windows disk.

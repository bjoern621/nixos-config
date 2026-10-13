# fractal

Gaming desktop with Windows 11 and NixOS on separate NVMe disks.
The firmware boot menu picks the disk; neither boot loader knows about the other.

## Disks

| Disk | Holds |
| --- | --- |
| Crucial T700 2 TB | NixOS: an ESP (partlabel `ESP`) and a LUKS root (partlabel `cryptroot`, ext4 inside). The TPM unlocks the root, bound to Secure Boot state. |
| Samsung 990 PRO 4 TB | Windows on the first 2 TB with its own ESP, then a LUKS ext4 volume mounted at `/games`, partlabel `games`, opened with the key file at `/etc/luks/games.key`. |

## Installing Windows

Windows comes first, with the T700 out of its M.2 slot.
The Windows installer puts its boot files onto an ESP it finds on any disk, and the T700 would otherwise end up carrying them.

1. Pull the T700 from its slot.
2. Boot the Windows 11 installer and choose the custom installation.
   Delete every partition on the 990 PRO, create one partition of 2 TB and leave the rest unallocated.
   The installer adds its own ESP, MSR and recovery partitions next to it.
3. Setup carries no driver for the board's MediaTek Wi-Fi.
   At the network screen press Shift+F10, install the ASUS MT7925 driver from a USB stick and go back one screen:

    ```bat
    rem Windows setup, Shift+F10
    pnputil /add-driver E:\<driver folder>\mtkwecx.inf /install
    ```

4. At the account screen press Shift+F10 and run `start ms-cxh:localonly` to create a local account.
   A local account skips Device Encryption, which would otherwise bind the disk to the TPM and ask for a recovery key after every Secure Boot change.
5. After the first login, confirm that encryption is off and disable it where it is on:

    ```powershell
    # Windows, elevated PowerShell
    manage-bde -status C:
    manage-bde -off C:
    ```

6. Put the T700 back.

## Installing NixOS

The install follows the README's installation steps, with the disk prepared by hand.
Two disks sit in the machine, and the one holding Windows stays untouched throughout.

1. In the firmware, set Secure Boot Mode to Custom and clear the Secure Boot keys (Boot, Secure Boot, Key Management).
   On Standard the firmware reinstalls its factory keys at the next boot.
   With no platform key the firmware sits in setup mode and boots the unsigned installer and the first system.
   The flake configuration enrolls its own keys together with the Microsoft ones on its first boot and reboots with Secure Boot on.
2. Boot the NixOS minimal ISO from a USB stick and find the T700:

    ```sh
    ls -l /dev/disk/by-id/ | grep CT2000T700
    ```

    Every command below names that path, and the 990 PRO appears in none of them.

3. Partition, encrypt, format and mount.
   This wipes the T700.

    ```sh
    # installer, as root
    disk=/dev/disk/by-id/nvme-CT2000T700SSD3_<serial>
    sgdisk --zap-all "$disk"
    sgdisk --new=1:0:+1G --typecode=1:EF00 --change-name=1:ESP "$disk"
    sgdisk --new=2:0:0 --typecode=2:8309 --change-name=2:cryptroot "$disk"
    udevadm settle
    cryptsetup luksFormat --type luks2 /dev/disk/by-partlabel/cryptroot
    cryptsetup open /dev/disk/by-partlabel/cryptroot cryptroot
    mkfs.ext4 -L nixos /dev/mapper/cryptroot
    mkfs.fat -F 32 -n ESP /dev/disk/by-partlabel/ESP
    mount /dev/mapper/cryptroot /mnt
    mount --mkdir -o umask=0077 /dev/disk/by-partlabel/ESP /mnt/boot
    ```

    The mapper name `cryptroot` lands in the hardware file, and `hosts/fractal/configuration.nix` lists it for the TPM unlock.
    The passphrase stays the fallback for a TPM that refuses to unlock, so it goes into the password manager.

4. Generate the hardware file and write a first system that boots and reaches the network:

    ```sh
    nixos-generate-config --root /mnt
    ```

    ```nix
    # /mnt/etc/nixos/configuration.nix
    { pkgs, ... }:

    {
      imports = [ ./hardware-configuration.nix ];

      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;

      networking.hostName = "fractal";
      networking.networkmanager.enable = true;

      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];

      users.users.bjoern = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "networkmanager"
        ];
        initialPassword = "fractal";
      };

      environment.systemPackages = [ pkgs.git ];

      system.stateVersion = "26.11";
    }
    ```

    Then `nixos-install --root /mnt`, which asks for the root password, and reboot without the stick.

5. On fractal, follow the README installation steps 4 to 8 with `HOST=fractal`: clone the repository, copy the hardware file into `hosts/fractal/` and mark it skip-worktree.

6. Place the two keys the configuration reads before the first switch.
   The sops age key decrypts the Attic token, and the games key opens the volume on the Windows disk:

    ```sh
    sudo install -d -m 700 /var/lib/sops-nix /etc/luks
    sudo nix shell nixpkgs#age --command age-keygen -o /var/lib/sops-nix/key.txt
    sudo sh -c 'head -c 64 /dev/urandom > /etc/luks/games.key'
    sudo chmod 600 /var/lib/sops-nix/key.txt /etc/luks/games.key
    sudo nix shell nixpkgs#age --command age-keygen -y /var/lib/sops-nix/key.txt
    ```

    On the laptop, add the printed public key to `.sops.yaml` as `host_fractal`, list it in the catch-all rule, run `sops updatekeys secrets/*.yaml`, commit and push.
    Pull on fractal.

7. Install the flake configuration as the next boot entry and reboot into it:

    ```sh
    sudo NIXOS_REBUILD_NO_SYSTEMD_RUN=1 nixos-rebuild boot --flake ~/git/nixos-config/hosts/fractal
    sudo reboot
    ```

    `nixos-rebuild` hands the switch to `systemd-run --output=cat`, and the installed system's older `systemd-run` rejects that option.
    Without `systemd-run` the switch would run inside the console login, so the configuration goes in as a boot entry.
    The first boot writes the Secure Boot keys to the ESP and reboots, and systemd-boot enrolls them on the boot after.
    The machine comes back with Secure Boot on, `bootctl status` showing `enabled (user)`, and logs `bjoern` straight into Hyprland.
    Set the password with `passwd` afterwards.

## After the first boot

Each step runs on fractal as root.

1. Enroll the TPM, after Secure Boot is on, since PCR 7 settles only then:

    ```sh
    systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-partlabel/cryptroot
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
6. As `bjoern`, copy the admin SSH key from Bitwarden as in README installation step 10.

## Games on NixOS

Steam, Heroic, Lutris and Prism Launcher install into `/games`, which each launcher takes as a library or install path in its settings.
Proton GE sits in Steam's compatibility tool list from the start.
Titles behind a kernel anti-cheat stay on the Windows disk.

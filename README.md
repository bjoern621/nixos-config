[![Update flake locks (stable)](https://github.com/bjoern621/nixos-config/actions/workflows/update-flake-locks.yml/badge.svg)](https://github.com/bjoern621/nixos-config/actions/workflows/update-flake-locks.yml)

# NixOS Configuration

Personal NixOS daily driver configuration featuring Hyprland, Home Manager, and Waybar.

## Installation

> [!IMPORTANT]
> Create the correct username during installation based on the selected host profile.
> For `nixos`, use user `bjoern`. For `homelab` or `vmk3s`, use user `ops`.
> Using a different username can cause the previous home files to be replaced after rebuild,
> which means cloning this repo and recreating symlinks must be done again.

1. Install NixOS using any preferred method, for example the graphical installer.
2. Boot into the installed system.
3. Install Git temporarily:
    ```bash
    nix-shell -p git
    ```
4. Clone this repository:
    ```bash
    git clone https://github.com/bjoern621/nixos-config.git ~/git/nixos-config
    ```
5. List available host names and pick one:
    ```bash
    ls ~/git/nixos-config/hosts
    ```
6. Set the host name as an environment variable:
    ```bash
    export HOST=<host>
    ```
7. Link the repository as the NixOS config directory:
    ```bash
    sudo ln -s ~/git/nixos-config /etc/nixos/config
    ```
8. Copy the hardware configuration into the selected host:
    ```bash
    sudo cp /etc/nixos/hardware-configuration.nix ~/git/nixos-config/hosts/$HOST/hardware-configuration.nix
    ```
9. Mark the hardware configuration as local-only so git ignores changes to it:
    ```bash
    git -C ~/git/nixos-config update-index --skip-worktree hosts/$HOST/hardware-configuration.nix
    ```
10. Apply the flake configuration:
    ```bash
    sudo nixos-rebuild switch --flake /etc/nixos/config/hosts/$HOST
    ```

## Raspberry Pi SD Card Hosts

Hosts that target Raspberry Pi hardware (e.g. `pi-4b-hh`) are provisioned by flashing a pre-built SD card image rather than running the NixOS installer. The image is built from the host's flake and boots directly into the configured system.

> [!IMPORTANT]
> Building requires aarch64 emulation on the build machine. The `nixos` host has `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]` configured for this. If the `nixos` host has not been rebuilt since that option was added, do so before building.

### Build the image

Run from any machine with the repo checked out:

```bash
nix build /path/to/hosts/<host>#sdImage
```

This produces a `result` symlink pointing to a compressed `.img.zst` file.

### Flash

**Using Raspberry Pi Imager:**

1. Decompress the image to a temporary file:
    ```bash
    zstdcat result/sd-image/*.img.zst > /tmp/<host>.img
    ```
2. Open Raspberry Pi Imager, select **Use custom**, and pick `/tmp/<host>.img`.

**Using `dd` directly:**

```bash
# Verify the SD card device first
lsblk

zstdcat result/sd-image/*.img.zst | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

### First boot

Insert the card and power on the Pi. The system boots directly into the NixOS configuration with no manual installation steps. Default credentials: user `ops`, password `1234` - change the password after first login.

On first boot, a systemd service (`nixos-config-setup`) clones the repository to `/etc/nixos/config` automatically (requires internet access). Once it completes, `sysconf-pull` and `sysconf-reload` are ready to use. Check its status with:

```bash
systemctl status nixos-config-setup
```

## Troubleshooting

### Boot hangs on "waiting for device" after install

If the system stalls at boot with a message like `waiting for device /dev/disk/by-uuid/...`, the hibernate resume device is probably misconfigured. The swap file's backing partition UUID and resume offset in the host configuration still point to the old/default values and need to be updated to match this machine.

**Quick fix**: temporarily disable hibernate to get the system booting:

In `hosts/$HOST/configuration.nix`, set `system.hibernate.enable = false`, then rebuild.

**Long-term fix**: the swap file must exist before its resume offset can be read, so this requires two rebuilds.

*Phase 1*: enable hibernate with only `size` set (no `resumeDevice`/`resumeOffset`) so the swap file gets created, then rebuild:

```nix
system.hibernate = {
  enable = true;
  swapFile.size = 32; # GB, should be >= RAM
};
```

```bash
sysconf-reload
```

*Phase 2*: read the UUID and offset, fill them in, then rebuild again:

```bash
# UUID of the filesystem containing the swap file (the decrypted LUKS volume on LUKS setups)
sudo blkid $(df /swapfile | tail -1 | awk '{print $1}') | grep -o 'UUID="[^"]*"' | cut -d'"' -f2

# Resume offset
sudo filefrag -v /swapfile | awk 'NR==4 { print $4 }' | tr -d '.'
```

```nix
system.hibernate.swapFile = {
  resumeDevice = "/dev/disk/by-uuid/<UUID>";
  resumeOffset = <offset>;
};
```

```bash
sysconf-reload
```

## Usage

### Rebuild System

```bash
sysconf-reload                # auto-detect host from /etc/hostname
sysconf-reload homelab        # explicit host override
```

### Update Flake Inputs

```bash
sysconf-update         # update flake inputs to latest revisions, then rebuild
sysconf-stable-update  # update inputs to revisions at least 7 days old (ensure stability), then rebuild
```

## Project Structure

Each host has its own flake under `hosts/<host>/` with an independent `flake.lock`,
so the server hosts only pull `nixpkgs` and `home-manager` instead of the full
desktop input set. The top-level `flake.nix` exposes only the repo dev shell.

```
.
├── flake.nix                       # Repo dev shell (`nix develop`)
├── flake.lock
├── hosts/
│   ├── nixos/                      # Daily driver, full input set
│   │   ├── flake.nix
│   │   ├── flake.lock
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix
│   ├── homelab/                    # Server, nixpkgs + home-manager only
│   │   ├── flake.nix
│   │   ├── flake.lock
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix
│   ├── vmk3s/                      # Server, nixpkgs + home-manager only
│   │   ├── flake.nix
│   │   ├── flake.lock
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix
│   └── pi-4b-hh/                   # Raspberry Pi 4, SD card image
│       ├── flake.nix               # exposes packages.<system>.sdImage
│       ├── flake.lock
│       ├── configuration.nix
│       └── hardware-configuration.nix
├── modules/                        # Shared system-level modules
├── home/                           # Shared Home Manager configs
│   ├── bjoern.nix                  # User config for the `nixos` host
│   ├── ops.nix                     # User config for the server hosts
│   └── modules/
└── README.md
```

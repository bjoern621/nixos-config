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
9. Mark the hardware configuration as local-only so git ignores your changes to it:
    ```bash
    git -C ~/git/nixos-config update-index --skip-worktree hosts/$HOST/hardware-configuration.nix
    ```
10. Apply the flake configuration:
    ```bash
    sudo nixos-rebuild switch --flake /etc/nixos/config#$HOST
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

```
.
├── flake.nix                     # Flake configuration
├── hosts/
│   └── nixos/
│       ├── configuration.nix     # System configuration
│       └── hardware-configuration.nix
├── modules/                      # System-level modules
├── home/                         # Home Manager configs
│   ├── bjoern.nix
│   └── modules/
└── README.md
```

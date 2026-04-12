# NixOS Configuration

Personal NixOS daily driver configuration featuring Hyprland, Home Manager, and Waybar.

## Installation

> [!IMPORTANT]
> Create the correct username during installation based on the selected host profile.
> For `default`, use user `bjoern`. For `homelab` or `vmk3s`, use user `ops`.
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
5. Link the repository as the NixOS config directory:
    ```bash
    sudo ln -s ~/git/nixos-config /etc/nixos/config
    ```
6. Copy the hardware configuration into the selected host:
    ```bash
    sudo cp /etc/nixos/hardware-configuration.nix ~/git/nixos-config/hosts/<host>/hardware-configuration.nix
    ```
7. Apply the flake configuration:
    ```bash
    sudo nixos-rebuild switch --flake /etc/nixos/config#<host>
    ```

List available host names with:

```bash
ls ~/git/nixos-config/hosts
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
│   └── default/
│       ├── configuration.nix     # System configuration
│       └── hardware-configuration.nix
├── modules/                      # System-level modules
├── home/                         # Home Manager configs
│   ├── bjoern.nix
│   └── modules/
└── README.md
```

## Adding Applications

**System packages**: Edit `hosts/default/configuration.nix`
**User packages**: Edit `home/bjoern.nix` or create modules in `home/modules/`

## License

MIT

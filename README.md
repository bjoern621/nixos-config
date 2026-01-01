# NixOS Configuration

Personal NixOS daily driver configuration featuring Hyprland, Home Manager, and Waybar.

## Installation

### Fresh NixOS Install

1. Boot from NixOS ISO and install normally
2. Generate base config: `sudo nixos-generate-config --root /mnt`
3. Clone this repository to your user folder:
    ```bash
    git clone https://github.com/YOUR_USERNAME/nixos-config.git ~/git/nixos-config
    cd ~/git/nixos-config
    ```
4. Create symlink and copy hardware config:
    ```bash
    sudo ln -s ~/git/nixos-config /etc/nixos/config
    sudo cp /mnt/etc/nixos/hardware-configuration.nix ~/git/nixos-config/hosts/default/
    ```
5. Install: `sudo nixos-install --flake /etc/nixos/config#nixos`
6. Reboot

### Add to Existing System

```bash
git clone <your-repo> ~/git/nixos-config
sudo ln -s ~/git/nixos-config /etc/nixos/config
sudo cp /etc/nixos/hardware-configuration.nix ~/git/nixos-config/hosts/default/
sudo nixos-rebuild switch --flake /etc/nixos/config#nixos
```

## Usage

### Rebuild System

```bash
sudo nixos-rebuild switch --flake /etc/nixos/config#nixos
```

### Test Changes (No Reboot Persistence)

```bash
sudo nixos-rebuild test --flake /etc/nixos/config#nixos
```

### Update Flake Inputs

```bash
nix flake update /etc/nixos/config
```

## Helper Scripts

The following scripts are installed system-wide:

-   `sysconf-reload` - Sync hardware config and rebuild only
-   `sysconf-update` - Update flake inputs to latest versions
-   `sysconf-pull` - Pull latest changes from git repository
-   `sysconf-help` - Show help for all sysconf commands

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

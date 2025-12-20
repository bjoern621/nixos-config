# NixOS Configuration

A NixOS system configuration featuring Hyprland window manager with Home Manager for user-level package management.

## Features

-   Hyprland (Wayland compositor)
-   Home Manager integration
-   Waybar, Wofi, Dunst pre-configured
-   User-level applications: Spotify, Discord
-   German locale and keyboard layout

## Project Structure

```
.
├── flake.nix                     # Flake configuration
├── hosts/
│   └── default/
│       ├── configuration.nix     # System configuration
│       └── hardware-configuration.nix
├── modules/
│   └── hyprland.nix              # Hyprland system module
├── home/
│   ├── bjoern.nix                # User home configuration
│   └── modules/
│       ├── hyprland.nix          # Hyprland user config
│       ├── spotify.nix           # Spotify
│       └── discord.nix           # Discord
└── README.md
```

## Installation Guide

### 1. Download NixOS

1. Go to [nixos.org/download](https://nixos.org/download/)
2. Download the **Minimal ISO image** (recommended) or Graphical installer
3. Create a bootable USB drive:
    - Linux/macOS: `sudo dd if=nixos-*.iso of=/dev/sdX bs=4M status=progress`
    - Windows: Use [Rufus](https://rufus.ie/) or [Etcher](https://etcher.io/)

### 2. Boot and Partition

1. Boot from the USB drive
2. Connect to the internet:

    ```bash
    # For WiFi
    sudo systemctl start wpa_supplicant
    wpa_cli
    > add_network
    > set_network 0 ssid "YOUR_SSID"
    > set_network 0 psk "YOUR_PASSWORD"
    > enable_network 0
    > quit

    # Or use nmtui for NetworkManager
    sudo nmtui
    ```

3. Partition the disk (example for UEFI with GPT):

    ```bash
    # List disks
    lsblk

    # Partition (replace /dev/nvme0n1 with the disk)
    sudo parted /dev/nvme0n1 -- mklabel gpt
    sudo parted /dev/nvme0n1 -- mkpart root ext4 512MB 100%
    sudo parted /dev/nvme0n1 -- mkpart ESP fat32 1MB 512MB
    sudo parted /dev/nvme0n1 -- set 2 esp on
    ```

4. Format the partitions:

    ```bash
    sudo mkfs.ext4 -L nixos /dev/nvme0n1p1
    sudo mkfs.fat -F 32 -n boot /dev/nvme0n1p2
    ```

5. Mount the partitions:
    ```bash
    sudo mount /dev/disk/by-label/nixos /mnt
    sudo mkdir -p /mnt/boot
    sudo mount /dev/disk/by-label/boot /mnt/boot
    ```

### 3. Generate Initial Configuration

```bash
sudo nixos-generate-config --root /mnt
```

### 4. Clone This Repository

```bash
# Install git temporarily
nix-shell -p git

# Clone the repository
sudo git clone https://github.com/YOUR_USERNAME/nixos-config.git /mnt/etc/nixos

# Copy the generated hardware configuration
sudo cp /mnt/etc/nixos/hardware-configuration.nix.bak /mnt/etc/nixos/hosts/default/hardware-configuration.nix

# Or manually copy it
sudo cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/hosts/default/
```

### 5. Install NixOS

```bash
sudo nixos-install --flake /mnt/etc/nixos#nixos
```

When prompted, set the root password.

### 6. Post-Installation

1. Reboot into the new system:

    ```bash
    sudo reboot
    ```

2. Log in as root and set user password:

    ```bash
    passwd bjoern
    ```

3. Log out and log in as `bjoern`

## Usage

### Rebuild the System

After making changes to the configuration:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

### Update Flake Inputs

```bash
nix flake update /etc/nixos
```

### Rebuild with Updates

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos --upgrade
```

## Hyprland Keybindings

| Keybinding            | Action                           |
| --------------------- | -------------------------------- |
| `SUPER + Return`      | Open terminal (Kitty)            |
| `SUPER + D`           | Open application launcher (Wofi) |
| `SUPER + Q`           | Close window                     |
| `SUPER + V`           | Toggle floating                  |
| `SUPER + M`           | Exit Hyprland                    |
| `SUPER + 1-0`         | Switch to workspace 1-10         |
| `SUPER + SHIFT + 1-0` | Move window to workspace         |
| `SUPER + Arrow keys`  | Move focus                       |
| `Print`               | Screenshot selection             |
| `SHIFT + Print`       | Screenshot full screen           |

## Adding More Applications

### System-level packages

Edit `hosts/default/configuration.nix`:

```nix
environment.systemPackages = with pkgs; [
  # Add packages here
];
```

### User-level packages

Edit `home/bjoern.nix`:

```nix
home.packages = with pkgs; [
  # Add packages here
];
```

Or create a new module in `home/modules/` and import it in `home/bjoern.nix`.

## Troubleshooting

### Hardware configuration missing

Copy the auto-generated hardware configuration:

```bash
sudo cp /etc/nixos/hardware-configuration.nix /etc/nixos/hosts/default/
```

### Flakes not enabled

If flakes are not enabled in the installer:

```bash
nix --experimental-features "nix-command flakes" flake update
```

### Display issues

If the display manager does not start:

1. Switch to TTY with `Ctrl + Alt + F2`
2. Check logs: `journalctl -xeu display-manager`
3. Ensure GPU drivers are installed in `hardware-configuration.nix`

## License

MIT

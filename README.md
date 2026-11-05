[![Update flake locks (stable)](https://github.com/bjoern621/nixos-config/actions/workflows/update-flake-locks.yml/badge.svg)](https://github.com/bjoern621/nixos-config/actions/workflows/update-flake-locks.yml)

![vmk3s](https://img.shields.io/endpoint?url=https%3A%2F%2Fstatus.bjoernblessin.de%2Fbadge%2Fvmk3s.json) ![netcup-g12](https://img.shields.io/endpoint?url=https%3A%2F%2Fstatus.bjoernblessin.de%2Fbadge%2Fnetcup-g12.json) ![hetzner-hel1](https://img.shields.io/endpoint?url=https%3A%2F%2Fstatus.bjoernblessin.de%2Fbadge%2Fhetzner-hel1.json) ![pi-4b-hh](https://img.shields.io/endpoint?url=https%3A%2F%2Fstatus.bjoernblessin.de%2Fbadge%2Fpi-4b-hh.json) ![homelab](https://img.shields.io/endpoint?url=https%3A%2F%2Fstatus.bjoernblessin.de%2Fbadge%2Fhomelab.json)

# NixOS Configuration

This repository configures my machines with NixOS and Home Manager: a Hyprland laptop as daily driver, a gaming desktop and a small fleet of servers.
Every host tracks `nixos-unstable` and builds from its own flake under `hosts/`.

## What it sets up

- Hyprland desktop, configured in Lua, with a Quickshell bar, launcher, notifications and lock screen
- Secure Boot through Lanzaboote and TPM unlock of the encrypted root
- Face login through Howdy and FIDO2 security keys
- USB device control through USBGuard
- Hibernate on lid close
- k3s cluster across a home VM and cloud servers, joined over Tailscale
- Binary cache on a self-hosted Attic server
- Secrets in sops-encrypted files, with a committed template for each
- Scheduled pull of `origin/main` on every host, followed by a rebuild
- Scheduled GitHub Actions workflow that pins aged flake inputs, builds the hosts and merges the pins that pass

## Hosts

| Host | Machine | Install route |
| --- | --- | --- |
| `nixos` | Laptop, daily driver | [NixOS installer](docs/installation.md) |
| `fractal` | Gaming desktop, CI runner | [NixOS installer](docs/installation.md) |
| `homelab` | Home server, hosts `vmk3s` as a libvirt guest | [NixOS installer](docs/installation.md) |
| `vmk3s` | k3s server | [NixOS installer](docs/installation.md) |
| `netcup-g12` | k3s agent, netcup VPS | [Cloud install](docs/k3s-cluster.md#installing-a-cloud-host) |
| `hetzner-hel1` | k3s agent, Hetzner Cloud VM | [Cloud install](docs/k3s-cluster.md#installing-a-cloud-host) |
| `pi-4b-hh` | Raspberry Pi 4, backup target | [SD card image](docs/raspberry-pi-sd-card.md) |

The host badges at the top show the revision installed on each host, colored by how far the host lags `origin/main` measured against its own sync schedule.
The fleet badge endpoint behind them lives in `hh-cluster-infra` (status-proxy application).

## Installation

Follow [docs/installation.md](docs/installation.md), which covers the steps that every host takes and the work by hand that each module needs.
Desktop hosts and hosts with secrets need keys kept outside this repository.

## Usage

```bash
sysconf-reload                # Rebuild the host named in /etc/hostname
sysconf-reload homelab        # Rebuild the named host
sysconf-update                # Update this host's flake inputs, then rebuild
sysconf-pull                  # Fast-forward to origin, then rebuild. Aborts on local commits.
sysconf-pull --hard           # Reset to origin, discarding local commits and changes, then rebuild
sysconf-help                  # List every sysconf command
```

### Deploy to another machine

`--remote` turns a bare NixOS machine into one of these hosts.
The system builds on this machine and activates on the target over ssh:

```bash
sysconf-reload netcup-g12 --remote root@203.0.113.9
```

The command must name both the host and the address.
An alias in `~/.ssh/config` shortens the address, as in `--remote netcup-g12`.
The target must hold `/etc/nixos/hardware-configuration.nix`, which the script copies from there before the build.

A host that enables `sysconf.checkout` clones the repository on that first activation and can run `sysconf-reload` on its own afterwards.

## Hardware configuration

> [!CAUTION]
> A machine's real `hardware-configuration.nix` never goes into git.
> Git carries a placeholder at `hosts/<host>/hardware-configuration.nix`.
> The placeholder stays.

Each machine keeps its real file at `/etc/nixos/hardware-configuration.nix`.
`sysconf-reload` copies it over the placeholder before every build.
`skip-worktree` keeps the copy out of `git status` and out of commits.
A `--remote` deploy copies the target's file over ssh and restores the previous file on exit.

A machine without the file, such as one installed from an image, must generate it once as root:

```bash
nixos-generate-config --show-hardware-config > /etc/nixos/hardware-configuration.nix
```

CI builds each host's `-ci` attribute, which layers a hardware stub over the placeholder.

## Project structure

Each host has its own flake and `flake.lock`, so a server pulls only the inputs that it uses.
The top-level `flake.nix` exposes the repo dev shell alone.

```
.
├── flake.nix                       # Repo dev shell (`nix develop`)
├── flake.lock
├── hosts/
│   └── <host>/
│       ├── flake.nix               # Inputs and system outputs of this host
│       ├── flake.lock
│       ├── configuration.nix
│       ├── home.nix                # Home Manager modules, desktop hosts
│       └── hardware-configuration.nix
├── modules/                        # Shared system-level modules
├── home/                           # Shared Home Manager configs
│   ├── bjoern.nix                  # User config shared by the desktop hosts
│   ├── ops.nix                     # User config for the server hosts
│   └── modules/
├── lib/                            # Shared Nix helpers
├── pkgs/                           # Custom packages
├── secrets/                        # sops-encrypted values and their templates
└── docs/                           # Setup guides and feature notes
```

## Further reading

- [k3s cluster nodes](docs/k3s-cluster.md)
- [Howdy face login](docs/howdy-face-login.md)
- [Keyring auto-unlock](docs/keyring-auto-unlock.md)
- [Contributing guidelines](CONTRIBUTING.md)

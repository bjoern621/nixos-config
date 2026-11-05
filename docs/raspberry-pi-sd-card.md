# Raspberry Pi SD card hosts

This guide installs a Raspberry Pi host, such as `pi-4b-hh`, from a pre-built SD card image.
The image comes from the host's flake and boots directly into the configured system.

> [!IMPORTANT]
> The build machine must emulate aarch64.
> The `nixos` host sets `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]` for this.

## Build the image

Run this on a machine with the repository checked out:

```bash
nix build /path/to/hosts/<host>#sdImage
```

The compressed image lands at `result/sd-image/*.img.zst`.

## Flash the card

With Raspberry Pi Imager:

1. Decompress the image to a temporary file:
    ```bash
    zstdcat result/sd-image/*.img.zst > /tmp/<host>.img
    ```
2. Open Raspberry Pi Imager, select **Use custom** and pick `/tmp/<host>.img`.

With `dd`:

```bash
# Verify the SD card device first
lsblk

zstdcat result/sd-image/*.img.zst | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

## First boot

Insert the card and power on the Pi.
Log in as `ops` with password `1234`, then change the password.

On first boot, the `sysconf-checkout` service clones the repository to the path that the host sets as `sysconf.configPath`.
The Pi must reach the internet for the clone.
Check its status:

```bash
systemctl status sysconf-checkout
```

`sysconf-pull` and `sysconf-reload` need the finished clone.
You must also generate `/etc/nixos/hardware-configuration.nix` once (see [Hardware configuration](../README.md#hardware-configuration)).

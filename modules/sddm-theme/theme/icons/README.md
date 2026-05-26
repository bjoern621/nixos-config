# Icons

The `icons8-*.svg` files in this folder are encrypted with [git-crypt](https://github.com/AGWA/git-crypt) because they are licensed assets and cannot be distributed publicly.

## Icons

| File | Used for |
|------|----------|
| `icons8-face-id.svg` | Face unlock button |
| `icons8-password-key.svg` | Password field |
| `icons8-spinner.svg` | Loading/authenticating spinner |

## Decrypting

Requires `git-crypt` and the symmetric key (stored as base64 text).

**1. Restore the key from base64:**

```sh
mkdir -p ~/.config/git-crypt
base64 -d ~/.config/git-crypt/nixos-config-key.b64 > ~/.config/git-crypt/nixos-config-key
chmod 600 ~/.config/git-crypt/nixos-config-key
```

**2. Unlock the repo:**

```sh
nix develop
git-crypt unlock ~/.config/git-crypt/nixos-config-key
```

After unlocking, the SVGs are transparently decrypted on checkout and re-encrypted on commit.

## Re-locking

```sh
git-crypt lock
```

## Backing up / sharing the key

The key is stored as a base64 text file at `~/.config/git-crypt/nixos-config-key.b64`. Copy its contents into a password manager for safekeeping.

To regenerate the base64 string from the binary key at any time:

```sh
base64 ~/.config/git-crypt/nixos-config-key
```

## How it works

`.gitattributes` marks all `icons8-*.svg` files in this folder with the `git-crypt` filter. On push they are AES-256 encrypted blobs; locally (after unlock) they are plain SVG files.

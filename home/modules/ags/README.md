# AGS Configuration

## Development Setup

To edit the TypeScript/TSX files with full type support, run:

```bash
ags types -u -d .
```

This generates the `@girs/` type declarations and `node_modules/` symlinks required for IDE autocompletion and type checking.

**Important:** TypeScript definitions are generated for the types inside `extraPackages` defined in the AGS Nix configuration. To add new type definitions:

1. Add the desired packages to `extraPackages` in the config
2. Reload the NixOS configuration to install the new packages
3. Run `ags types -u -d .` to generate the corresponding type definitions

## Usage

For normal usage (applying the configuration), no setup is required. The NixOS configuration handles everything automatically.

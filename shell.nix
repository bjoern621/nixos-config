# Shim for tools that use nix-shell (e.g. nix-env-selector VS Code extension).
# Delegates to the devShell defined in flake.nix.
(builtins.getFlake (toString ./.)).devShells.${builtins.currentSystem}.default

{
  description = "nixos-config repo dev shell";

  # Per-host system configurations live under hosts/<name>/flake.nix so each
  # host's flake.lock tracks only the inputs that host references:
  #   nixos-rebuild switch --flake /etc/nixos/config/hosts/nixos
  #   nixos-rebuild switch --flake /etc/nixos/config/hosts/homelab
  #   nixos-rebuild switch --flake /etc/nixos/config/hosts/vmk3s
  #
  # This flake exposes only the repo-level dev shell

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    quickshell = {
      url = "github:quickshell-mirror/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, quickshell, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      qs = quickshell.packages.x86_64-linux.default;
      qt = pkgs.qt6.qtdeclarative;
      qt5compat = pkgs.qt6.qt5compat;
      sddm = pkgs.kdePackages.sddm.unwrapped;
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        # Allows qmlls (and the VS Code qt-qml extension) to resolve Qt and Quickshell imports.
        # Without this, qmlls only searches standard FHS paths which don't exist on NixOS,
        # resulting in "unknown module" errors for every Qt import.
        QML_IMPORT_PATH = "${qt}/lib/qt-6/qml:${qs}/lib/qt-6/qml:${qt5compat}/lib/qt-6/qml:${sddm}/lib/qt-6/qml";

        packages = with pkgs; [
          # Python + packages for runtime deps e.g. spotify_api.py
          (python3.withPackages (ps: [
            ps.keyring
            ps.secretstorage
          ]))
          ruff # linter + formatter
          mypy # static type check

          # Nix
          nil # LSP server
          nixfmt # formatter

          nixd

          git-crypt

          # QML qmllint, qmlls, qmlformat + Quickshell modules for import resolution
          qt
          qs
          qt5compat
          sddm
        ];

        shellHook = ''
          echo "nixos-config dev shell"
          echo "  python3  $(python3 --version)"
          echo "  ruff     $(ruff --version)"
          echo "  mypy     $(mypy --version)"
          echo "  qmllint  $(qmllint --version 2>&1 | head -1)"

          # qmlls lives in a nix store path that changes on every rebuild, so VS Code's
          # qt-qml extension (configured with a static path) can't find it.
          # This wrapper at ~/.local/bin/qmlls stays stable and forwards to the current store path.
          mkdir -p "$HOME/.local/bin"
          printf '#!/bin/sh\nexec "%s/bin/qmlls" "$@"\n' "${qt}" > "$HOME/.local/bin/qmlls"
          chmod +x "$HOME/.local/bin/qmlls"
          echo "  ~/.local/bin/qmlls wrapper written"

          # Same trick for qtpaths: the VS Code qt-core extension pins an absolute
          # store path in qt-core.additionalQtPaths, which rots on GC/rebuild.
          printf '#!/bin/sh\nexec "%s/bin/qtpaths" "$@"\n' "${pkgs.qt6.qtbase}" > "$HOME/.local/bin/qtpaths"
          chmod +x "$HOME/.local/bin/qtpaths"
          echo "  ~/.local/bin/qtpaths wrapper written"
        '';
      };
    };
}

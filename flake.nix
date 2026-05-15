{
  description = "Personal NixOS daily driver configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    hyprland.url = "github:hyprwm/Hyprland";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-search-tv = {
      url = "github:3timeslazy/nix-search-tv";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    quickshell = {
      url = "github:quickshell-mirror/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixd = {
      url = "github:nix-community/nixd";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      quickshell,
      ...
    }@inputs:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      customLib = import ./lib/customLib.nix { inherit pkgs; };
      qs = quickshell.packages.x86_64-linux.default;
      qt = pkgs.qt6.qtdeclarative;
      qt5compat = pkgs.qt6.qt5compat;
      sddm = pkgs.kdePackages.sddm.unwrapped;
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        # Allows qmlls (and the VS Code qt-qml extension) to resolve Qt and Quickshell imports.
        # Without this, qmlls only searches standard FHS paths which don't existon NixOS,
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
          # Without it, no QML language server in VS Code (the bundled language server does not work because it can't find it's dependencies).
          mkdir -p "$HOME/.local/bin"
          printf '#!/bin/sh\nexec "%s/bin/qmlls" "$@"\n' "${qt}" > "$HOME/.local/bin/qmlls"
          chmod +x "$HOME/.local/bin/qmlls"
          echo "  ~/.local/bin/qmlls wrapper written"

          # Same trick for qtpaths: the VS Code qt-core extension pins an absolute
          # store path in qt-core.additionalQtPaths, which rots on GC/rebuild.
          # Point that setting at ~/.local/bin/qtpaths once and this wrapper keeps
          # it valid across rebuilds.
          printf '#!/bin/sh\nexec "%s/bin/qtpaths" "$@"\n' "${pkgs.qt6.qtbase}" > "$HOME/.local/bin/qtpaths"
          chmod +x "$HOME/.local/bin/qtpaths"
          echo "  ~/.local/bin/qtpaths wrapper written"
        '';
      };

      nixosConfigurations = {
        nixos = nixpkgs.lib.nixosSystem {
          modules = [
            ./hosts/nixos/configuration.nix

            {
              # https://wiki.hypr.land/Nix/Cachix/
              nix.settings = {
                extra-substituters = [ "https://hyprland.cachix.org" ];
                extra-trusted-substituters = [ "https://hyprland.cachix.org" ];
                extra-trusted-public-keys = [
                  "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
                ];
              };
            }

            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true; # Use the same nixpkgs instance as the system (avoids duplicate packages)
              home-manager.useUserPackages = true; # Install user packages to /etc/profiles instead of ~/.nix-profile
              home-manager.backupFileExtension = "backup"; # Rename existing files (like ~/.config/hypr/hyprland.conf) to *.backup instead of failing
              home-manager.users.bjoern = import ./home/bjoern.nix; # User-specific Home Manager configuration
              home-manager.extraSpecialArgs = { inherit inputs customLib; };
            }
          ];

          specialArgs = { inherit inputs customLib; }; # https://wiki.hypr.land/Nix/Hyprland-on-NixOS/
        };

        homelab = nixpkgs.lib.nixosSystem {
          modules = [
            ./hosts/homelab/configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.users.ops = import ./home/ops.nix;
              home-manager.extraSpecialArgs = { inherit inputs customLib; };
            }
          ];

          specialArgs = { inherit inputs customLib; };
        };

        vmk3s = nixpkgs.lib.nixosSystem {
          modules = [
            ./hosts/vmk3s/configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.users.ops = import ./home/ops.nix;
              home-manager.extraSpecialArgs = { inherit inputs customLib; };
            }
          ];

          specialArgs = { inherit inputs customLib; };
        };
      };
    };
}

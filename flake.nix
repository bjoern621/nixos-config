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

    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-search-tv,
      ...
    }@inputs:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [
          # Python — spotify_api.py runtime deps + linting/typing
          (pkgs.python3.withPackages (ps: [
            ps.keyring
            ps.secretstorage
          ]))
          pkgs.ruff # linter + formatter (replaces flake8 / black)
          pkgs.mypy # static type checker

          # Bash — setup-spotify.sh
          pkgs.shellcheck # static analysis
          pkgs.shfmt # formatter

          # Nix
          pkgs.nil # LSP server
          pkgs.nixfmt # formatter

          # QML — provides qmllint
          pkgs.kdePackages.qtdeclarative
        ];

        shellHook = ''
          echo "nixos-config dev shell"
          echo "  python3  $(python3 --version)"
          echo "  ruff     $(ruff --version)"
          echo "  mypy     $(mypy --version)"
          echo "  qmllint  $(qmllint --version 2>&1 | head -1)"
        '';
      };

      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/default/configuration.nix

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
            home-manager.extraSpecialArgs = { inherit inputs; }; # Pass flake inputs to home-manager modules
          }
        ];

        specialArgs = { inherit inputs; }; # https://wiki.hypr.land/Nix/Hyprland-on-NixOS/
      };
    };
}

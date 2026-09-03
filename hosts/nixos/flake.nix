{
  description = "nixos host (daily driver) - full input set";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # No nixpkgs.follows: cachix serves only builds against hyprland's own nixpkgs pin,
    # and unstable stdenv or glaze drift breaks the hypr stack.
    hyprland.url = "github:hyprwm/Hyprland";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-search-tv = {
      url = "github:3timeslazy/nix-search-tv";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Prebuilt nix-index database (weekly), avoids local index build
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
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
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The app package plus the kmsgrab CAP_SYS_ADMIN wrapper module.
    screen-sharing = {
      url = "github:bjoern621/screen-sharing";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      customLib = import ../../lib/customLib.nix { inherit pkgs; };

      baseModules = [
        ./configuration.nix

        inputs.screen-sharing.nixosModules.screenShare
        {
          programs.screenShare = {
            enable = true;
            user = "bjoern";
          };
        }

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
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.users.bjoern = import ../../home/bjoern.nix;
          home-manager.extraSpecialArgs = { inherit inputs customLib; };
        }
      ];

      mkSystem =
        modules:
        nixpkgs.lib.nixosSystem {
          modules = baseModules ++ modules;

          specialArgs = { inherit inputs customLib; }; # https://wiki.hypr.land/Nix/Hyprland-on-NixOS/
        };
    in
    {
      nixosConfigurations.nixos = mkSystem [ ];

      # What CI builds.
      # modules/howdy.nix pins opencv4Full to an enableVtk = false override,
      # a path no substituter carries and that compiles for around an hour on a runner.
      #
      # Three references reach that path, and all three have to go.
      # display-manager.nix and quickshell-lock.nix interpolate services.howdy.package
      # into their PAM stacks whether or not the service is on,
      # so the stub package keeps those strings resolvable.
      # linux-enable-ir-emitter links opencv on its own account.
      #
      # The workarounds in modules/howdy.nix therefore go unchecked here.
      nixosConfigurations.nixos-ci = mkSystem [
        (
          { lib, pkgs, ... }:
          {
            services.howdy.enable = lib.mkForce false;
            services.howdy.package = lib.mkForce pkgs.emptyDirectory;
            services.linux-enable-ir-emitter.enable = lib.mkForce false;
          }
        )
      ];
    };
}

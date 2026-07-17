{
  description = "nixos host (daily driver) - full input set";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # TEMPORARY: Hyprland flake broken (missing default-linux/flake.nix).
    # Using nixpkgs.hyprland until upstream pin is fixed.
    # Revert by uncommenting below and restoring hyprland module to:
    #   inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland
    # hyprland = {
    #   url = "github:hyprwm/Hyprland/179c2bce0355289c60271fb00b89f2d5511618d5";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

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
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        modules = [
          ./configuration.nix

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

        specialArgs = { inherit inputs customLib; }; # https://wiki.hypr.land/Nix/Hyprland-on-NixOS/
      };
    };
}

{
  description = "Personal NixOS daily driver configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    hyprland.url = "github:hyprwm/Hyprland";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

    nix-search-tv = {
      url = "github:3timeslazy/nix-search-tv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, hyprland-plugins, nix-search-tv, ... } @ inputs: {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ./hosts/default/configuration.nix

          {
            # https://wiki.hypr.land/Nix/Cachix/
            nix.settings = {
              extra-substituters = ["https://hyprland.cachix.org"];
              extra-trusted-substituters = ["https://hyprland.cachix.org"];
              extra-trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
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

        specialArgs = { inherit inputs; }; # https://wiki.hypr.land/0.41.2/Nix/Hyprland-on-NixOS/
      };
    };
}

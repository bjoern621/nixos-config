{
  description = "Personal NixOS daily driver configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/default/configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true; # Use the same nixpkgs instance as the system (avoids duplicate packages)
            home-manager.useUserPackages = true; # Install user packages to /etc/profiles instead of ~/.nix-profile
            home-manager.backupFileExtension = "backup"; # Rename existing files (like ~/.config/hypr/hyprland.conf) to *.backup instead of failing
            home-manager.users.bjoern = import ./home/bjoern.nix; # User-specific Home Manager configuration
          }
        ];
      };
    };
}

{
  description = "pi-4b-hh host - aarch64 Raspberry Pi backup target";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nixos-hardware,
      ...
    }@inputs:
    let
      system = "aarch64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      customLib = import ../../lib/customLib.nix { inherit pkgs; };
    in
    {
      nixosConfigurations.pi-4b-hh = nixpkgs.lib.nixosSystem {
        inherit system;

        modules = [
          ./configuration.nix
          nixos-hardware.nixosModules.raspberry-pi-4
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.ops = import ../../home/ops.nix;
            home-manager.extraSpecialArgs = { inherit inputs customLib; };
          }
        ];

        specialArgs = { inherit inputs customLib; };
      };
    };
}

{
  description = "vmk3s host - minimal input set";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
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
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.users.ops = import ../../home/ops.nix;
          home-manager.extraSpecialArgs = { inherit inputs customLib; };
        }
      ];

      mkSystem =
        modules:
        nixpkgs.lib.nixosSystem {
          modules = baseModules ++ modules;
          specialArgs = { inherit inputs customLib; };
        };
    in
    {
      nixosConfigurations.vmk3s = mkSystem [ ];

      # What CI builds.
      # The machine's hardware-configuration.nix reaches the repo only on the machine,
      # so a runner needs the stub to get as far as the package set.
      nixosConfigurations.vmk3s-ci = mkSystem [ ../../modules/ci-hardware-stub.nix ];
    };
}

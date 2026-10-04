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

      baseModules = [
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

      mkSystem = modules: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = baseModules ++ modules;
        specialArgs = { inherit inputs customLib; };
      };

      sdImage =
        (mkSystem [ "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix" ]).config.system.build.sdImage;
    in
    {
      nixosConfigurations.pi-4b-hh = mkSystem [ ];

      # What CI builds.
      # The machine's hardware-configuration.nix reaches the repo only on the machine,
      # so a runner needs the stub to get as far as the package set.
      # Stub defaults to x86_64-linux.
      nixosConfigurations.pi-4b-hh-ci = mkSystem [
        ../../modules/ci-hardware-stub.nix
        { nixpkgs.hostPlatform = system; }
      ];

      packages.aarch64-linux.sdImage = sdImage;
      packages.x86_64-linux.sdImage = sdImage;
    };
}

{
  description = "netcup-g12 host - minimal input set";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # The k3s join token is a secret, and the agent reads it out of a file rather than a
    # flag in the store. This host decrypts with its own ssh host key, so there is no key to
    # place before the first deploy.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, ... }@inputs:
    {
      nixosConfigurations.netcup-g12 = nixpkgs.lib.nixosSystem {
        modules = [ ./configuration.nix ];

        specialArgs = { inherit inputs; };
      };

      # First boot only: what the uploaded qcow2 carries.
      # The machine's facts and the server baseline, none of its services, so the same
      # pair of modules bootstraps any other host.
      #
      #   nixos-rebuild build-image --image-variant qemu-efi --flake .#netcup-g12-bootstrap
      #
      # Everything after that arrives over ssh with `sysconf-reload netcup-g12 --remote`.
      nixosConfigurations.netcup-g12-bootstrap = nixpkgs.lib.nixosSystem {
        modules = [
          ./machine.nix
          ../../modules/server-base.nix
        ];

        specialArgs = { inherit inputs; };
      };
    };
}

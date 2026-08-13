{
  description = "netcup-g12 host - minimal input set";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # The relay's config file and the MediaMTX version it is written against.
    # That repository is private, so this is the one input that has to authenticate.
    # https over the git credential helper, which is what the remotes use; ssh keys
    # are not authorized against GitHub here.
    screen-sharing = {
      url = "git+https://github.com/bjoern621/screen-sharing.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The SRT passphrase is a secret, and the relay reads it as environment rather than out
    # of a config file in the store. This host decrypts with its own ssh host key, so there
    # is no key to place before the first deploy.
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

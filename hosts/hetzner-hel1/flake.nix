{
  description = "hetzner-hel1 host - minimal input set";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # The k3s join token is a secret, and the agent reads it out of a file rather than a
    # flag in the store. This host decrypts with its own ssh host key, placed by the
    # installer, so the token is encrypted to it ahead of the first boot.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixos-anywhere formats the disk from disko.nix and the running system mounts by it.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, ... }@inputs:
    {
      nixosConfigurations.hetzner-hel1 = nixpkgs.lib.nixosSystem {
        modules = [ ./configuration.nix ];

        specialArgs = { inherit inputs; };
      };

      # What CI builds.
      # The machine's hardware-configuration.nix reaches the repo only on the machine,
      # so a runner needs the stub to get as far as the package set.
      nixosConfigurations.hetzner-hel1-ci = nixpkgs.lib.nixosSystem {
        modules = [
          ./configuration.nix
          ../../modules/ci-hardware-stub.nix
        ];

        specialArgs = { inherit inputs; };
      };

      # First install only: what nixos-anywhere writes onto the wiped disk.
      # The machine's facts and the server baseline, none of its services.
      #
      #   nixos-anywhere --flake .#hetzner-hel1-bootstrap --target-host root@<address> \
      #     --extra-files <dir holding etc/ssh/ssh_host_ed25519_key> \
      #     --generate-hardware-config nixos-generate-config <dir>/etc/nixos/hardware-configuration.nix
      #
      # Everything after that arrives over ssh with `sysconf-reload hetzner-hel1 --remote`.
      nixosConfigurations.hetzner-hel1-bootstrap = nixpkgs.lib.nixosSystem {
        modules = [
          ./machine.nix
          ../../modules/server-base.nix
        ];

        specialArgs = { inherit inputs; };
      };
    };
}

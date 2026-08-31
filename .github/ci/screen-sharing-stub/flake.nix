{
  description = "screen-sharing stand-in for CI";

  # The real input is path:/home/bjoern/git/screen-sharing, a working tree no runner has.
  # `--override-input screen-sharing` swaps this in so hosts/nixos evaluates,
  # and it declares programs.screenShare only far enough for hosts/nixos to set it.
  # The kmsgrab CAP_SYS_ADMIN wrapper is therefore absent from what CI builds.
  #
  # Delete this flake and the override once the repo is published and the input is a github: URL.

  # Unread, and declared only because hosts/nixos points a `follows` at it.
  # Without it nix warns about an override for a non-existent input.
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { ... }:
    {
      nixosModules.screenShare =
        { lib, ... }:
        {
          options.programs.screenShare = {
            enable = lib.mkEnableOption "screen sharing";

            user = lib.mkOption {
              type = lib.types.str;
              description = "Account the wrapper is granted to.";
            };
          };
        };
    };
}

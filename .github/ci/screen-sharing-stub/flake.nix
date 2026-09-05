{
  description = "screen-sharing stand-in for CI";

  # `--override-input screen-sharing` swaps this in,
  # keeping the daily lock build off the real flake:
  # its mirrorme package overlays gst_all_1,
  # so every pin change rebuilds gtk4 and that world from source,
  # over an hour on a runner and prone to check phases that flake off-screen.
  # Declares just enough for hosts/nixos to evaluate:
  # programs.mirrorme.kmsgrab for modules/screen-sharing.nix,
  # empty packages.mirrorme for home/modules/screen-sharing.nix.
  # kmsgrab CAP_SYS_ADMIN wrapper and app absent from CI build.
  # The tradeoff: a renamed export in the real flake lands here only when CI turns red.

  # Resolves to the host's pin through the `follows` hosts/nixos declares.
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    {
      nixosModules.mirrorme =
        { lib, config, ... }:
        {
          options.programs.mirrorme.kmsgrab.enable = lib.mkEnableOption "kmsgrab capture wrapper";

          # Group hosts put users into via extraGroups.
          config.users.groups.mirrorme = lib.mkIf config.programs.mirrorme.kmsgrab.enable { };
        };

      packages.x86_64-linux.mirrorme = nixpkgs.legacyPackages.x86_64-linux.emptyDirectory;
    };
}

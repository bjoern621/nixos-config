{ ... }:

{
  # https://nixos.wiki/wiki/Storage_optimization
  # More info: https://www.reddit.com/r/NixOS/comments/1cunvdw/friendly_reminder_optimizestore_is_not_on_by/

  # Automatically creates hardlinks for identical files in the Nix store to save disk space.
  # If the expected execution time is missed, it's executed once the system is running again (https://github.com/NixOS/nix/issues/6033#issuecomment-1948924684)
  nix.optimise.automatic = true;
  nix.optimise.dates = [ "03:45" ];

  # Does the same as above, but on every build. This slows down the build process and is thus disabled.
  # See also discussion: https://github.com/NixOS/nix/issues/6033
  nix.settings.auto-optimise-store = false;

  nix.gc = {
    automatic = true; # GC deletes all unreachable store objects (manual)
    dates = "daily"; 
    options = "--delete-older-than 14d"; # Also delete profiles older than X. (Except for the current active generation.)
    persistent = true; # Catch up on missed runs of the service when the system was powered down
  };
}
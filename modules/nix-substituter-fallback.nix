# Substituter chain: cache.nixos.org, then own Attic cache, then a local build.
#
# Nix orders substituters by ascending Priority from their nix-cache-info.
# cache.nixos.org serves 40;
# modules/attic-push.nix pins 41 into the Attic URL so a server-side change cannot reorder them.
#
# Falling through to a local build needs `fallback`.
# A substituter that answers the narinfo query and then fails the NAR download is a failed
# substitution, and Nix aborts the rebuild instead of building:
#   some substitutes for the outputs of derivation '...' failed
{
  nix.settings = {
    fallback = true;

    # Counted per NAR, so 5 attempts with backoff against a dead cache costs minutes
    # before the build starts.
    download-attempts = 2;

    # Defaults are 15 s and 300 s, paid per path against a cache that answers and then stalls.
    connect-timeout = 5;
    stalled-download-timeout = 20;
  };
}

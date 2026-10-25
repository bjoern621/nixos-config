# Read-only substituter for the self-hosted Attic cache nix-cache.bjoernblessin.de/system.
# CI pushes every host closure it builds, and modules/attic-push.nix pushes what a host builds itself.
# Read is public, so pulling needs the URL and the cache public key alone.
#
# Pair with modules/nix-substituter-fallback.nix:
# without `fallback`, a cache that fails a NAR download aborts the rebuild.

let
  cacheHost = "https://nix-cache.bjoernblessin.de/system";
  # priority=41 pins this behind cache.nixos.org (40) whatever the server's
  # nix-cache-info reports.
  # attic push skips paths cache.nixos.org signs.
  # Asking Attic first would cost one 404 per nixpkgs path.
  cacheUrl = "${cacheHost}?priority=41";
  # From `attic cache info system`. name:base64.
  publicKey = "system:CVw1EsxUyFB1VSHALF4GzqhjuRXjwyeyQzFOfXML+ss=";
in
{
  nix.settings = {
    extra-substituters = [ cacheUrl ];
    # Both spellings: the daemon matches a URL an untrusted client passes verbatim.
    extra-trusted-substituters = [
      cacheUrl
      cacheHost
    ];
    extra-trusted-public-keys = [ publicKey ];
  };
}

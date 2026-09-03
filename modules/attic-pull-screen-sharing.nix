# Read-only substituter for the screen-sharing Attic cache. The screen-sharing
# repo's release workflow is the only pusher; this host only pulls.
#
# Push credentials for "system" (this machine's own cache) live in
# modules/attic-push.nix and stay separate from this file on purpose: a token
# scoped to "system" cannot push here even by accident.
{
  nix.settings = {
    extra-substituters = [ "https://nix-cache.bjoernblessin.de/screen-sharing" ];
    extra-trusted-public-keys = [
      "screen-sharing:0wAX2u4GPUvsZmRMsjut6HjhdYfBErcjQCHTXiJ0yPM="
    ];
  };
}

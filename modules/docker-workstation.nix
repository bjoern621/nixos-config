{ ... }:

# Docker on desktops, for local dev stacks and image builds.
# Not for servers: a long-stopped container there may be a workload.
{
  virtualisation.docker = {
    enable = true;
    # docker.socket starts daemon on first docker command.
    # Containers with restart policy stay down until then.
    enableOnBoot = false;
    # Same 14 days as nix.gc in cleanup.nix.
    # until= compares image creation, not last use: unused older images get pulled again.
    # No --volumes: named volumes hold local dev databases such as pidgemail-backend_postgres.
    autoPrune = {
      enable = true;
      flags = [
        "--all"
        "--filter"
        "until=336h"
      ];
    };
  };
}

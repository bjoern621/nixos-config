{ pkgs, ... }:

# Paint.NET via WinBoat — runs the latest Windows version inside a containerized
# Windows VM with seamless window integration (FreeRDP RemoteApp).
#
# First-time setup:
#   1. Launch WinBoat and complete the Windows installation wizard
#   2. Inside the Windows VM, download and install Paint.NET from https://getpaint.net
#   3. Use WinBoat's app integration to add Paint.NET as a seamless app
#
# Requires: Docker enabled at system level (virtualisation.docker.enable = true)
# and user in the "docker" group.
{
  home.packages = [
    pkgs.winboat
  ];
}

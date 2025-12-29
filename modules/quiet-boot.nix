{ config, pkgs, ... }:

{
  # Instantly select latest NixOS profile
  boot.loader.timeout = 0;
}

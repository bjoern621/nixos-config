{ pkgs, ... }:

{
  # Needed by Claude Code Vscode Extension.
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    zlib.dev
    fuse3
    icu
    nss
    openssl
    curl
    expat
  ];
}

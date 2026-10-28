{ lib, ... }:

# Unpacked Chrome extension: Medium paywall redirect, page for proxy tunnel errors.
# Loaded once by hand: chrome://extensions, Developer mode on, Load unpacked, /etc/chrome-helper.
# Chrome resolves symlinks in the loaded path, so /etc/chrome-helper stays a real directory.
# Files inside stay symlinks into the store and follow every rebuild after a Chrome restart.

let
  files = builtins.attrNames (builtins.readDir ./extension);
in
{
  environment.etc = lib.listToAttrs (
    map (f: lib.nameValuePair "chrome-helper/${f}" { source = ./extension + "/${f}"; }) files
  );
}

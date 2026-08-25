# Custom package helpers.
#
# Instantiated once in flake.nix and passed to all NixOS and Home Manager
# modules via specialArgs / extraSpecialArgs, the same way `inputs` is passed.
# Modules receive it by declaring `customLib` in their argument set.
#
# Example (module):
#
#   { pkgs, customLib, ... }:
#   let
#     wrapped = customLib.wrapWithPrivateDeps pkgs.quickshell {
#       binDeps  = [ pkgs.imagemagick ];
#       dataDeps = [ pkgs.font-awesome ];
#     };

{ pkgs }:

{
  # wrapWithPrivateDeps
  # ───────────────────
  # Wrap a pre-built binary so that its subprocess environment contains a
  # private set of runtime dependencies without polluting the user's global
  # environment.  The wrapped binary is a drop-in replacement: all other
  # files from the original package (man pages, desktop entries, …) are
  # preserved via symlinks.
  #
  # Arguments:
  #
  #   package   Derivation to wrap.
  #
  #   bin       Name of the binary inside $out/bin/ to wrap.
  #             Defaults to package.meta.mainProgram, then package.pname,
  #             then the parsed derivation name.  Override when the binary
  #             name differs from those attributes.
  #
  #   binDeps   Derivations prepended to PATH.
  #             Use for programs called by the wrapped process at runtime.
  #
  #   dataDeps  Derivations prepended to XDG_DATA_DIRS.
  #             Use for fonts, GLib schemas, icon themes, and other share/
  #             resources loaded at runtime.
  #
  #   libDeps   Derivations prepended to LD_LIBRARY_PATH.
  #             Use for shared libraries that are dlopen-ed at runtime
  #             (prefer patchelf rpath for link-time deps instead).
  #
  #   gstDeps   Derivations prepended to GST_PLUGIN_PATH.
  #             Use for GStreamer plugins loaded at runtime.
  #
  #   giDeps    Derivations prepended to GI_TYPELIB_PATH.
  #             Use for GObject Introspection typelibs (.typelib files).
  #
  #   qtDeps    Derivations prepended to QT_PLUGIN_PATH.
  #             Use for Qt plugins loaded at runtime (image formats, platform themes).
  #
  #   env       Attribute set of arbitrary VAR = "value" pairs set via
  #             --set.  Use for any runtime variable not covered above.
  #
  # All dependency lists and env default to empty; omitting them produces
  # no wrapper arguments for that slot.  If nothing at all is specified,
  # postBuild is empty and the result is a plain symlinkJoin.
  #
  # Example:
  #
  #   customLib.wrapWithPrivateDeps pkgs.quickshell {
  #     binDeps  = [ pkgs.imagemagick qsPython ];
  #     dataDeps = [ pkgs.font-awesome pkgs.inter ];
  #   }

  wrapWithPrivateDeps =
    package:
    {
      bin ? pkgs.lib.getName package,
      binDeps ? [ ],
      dataDeps ? [ ],
      libDeps ? [ ],
      gstDeps ? [ ],
      giDeps ? [ ],
      qtDeps ? [ ],
      env ? { },
    }:
    let
      inherit (pkgs.lib)
        makeBinPath
        makeLibraryPath
        makeSearchPath
        optionalString
        mapAttrsToList
        escapeShellArg
        filter
        concatStringsSep
        ;

      wrapArgs = concatStringsSep " \\\n    " (
        filter (s: s != "") (
          [
            (optionalString (binDeps != [ ]) "--prefix PATH            : ${makeBinPath binDeps}")
            (optionalString (dataDeps != [ ]) "--prefix XDG_DATA_DIRS   : ${makeSearchPath "share" dataDeps}")
            (optionalString (libDeps != [ ]) "--prefix LD_LIBRARY_PATH : ${makeLibraryPath libDeps}")
            (optionalString (gstDeps != [ ]) "--prefix GST_PLUGIN_PATH : ${makeSearchPath "lib/gstreamer-1.0" gstDeps}")
            (optionalString (giDeps != [ ]) "--prefix GI_TYPELIB_PATH : ${makeSearchPath "lib/girepository-1.0" giDeps}")
            (optionalString (qtDeps != [ ]) "--prefix QT_PLUGIN_PATH  : ${makeSearchPath "lib/qt-6/plugins" qtDeps}")
          ]
          ++ mapAttrsToList (k: v: "--set ${k} ${escapeShellArg v}") env
        )
      );
    in
    pkgs.symlinkJoin {
      name = "${pkgs.lib.getName package}-wrapped";
      paths = [ package ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = optionalString (wrapArgs != "") ''
        wrapProgram $out/bin/${bin} \
          ${wrapArgs}
      '';
    };

}

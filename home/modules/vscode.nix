{ pkgs, ... }:

{
  programs.vscode.enable = true;

  # WORKAROUND (nixpkgs-unstable, vscode 1.136.1):
  # package ships `node_modules.asar` as symlink to `node_modules`,
  # and omits `node_modules.asar.unpacked`.
  # Built workbench fetches assets through that missing path.
  # Costs `vscode-oniguruma/release/onig.wasm`,
  # so TextMate tokenization fails and syntax highlighting dies in every language and every file.
  # Same path costs `@vscode/tree-sitter-wasm` and the Copilot CLI.
  # Every file exists under `node_modules/`, only the `.asar.unpacked` name is gone,
  # so one symlink restores all three.
  #
  # Symptom in `~/.config/Code/logs/<session>/window1/renderer.log`:
  # `Failed to fetch: TypeError: Failed to fetch at ..._loadVSCodeOnigurumaWASM`.
  # vscode 1.133.0 and 1.119.0 carry the real directory.
  #
  # Guard required: against a version that ships the directory,
  # a bare `ln -s` lands `node_modules.asar.unpacked/node_modules` inside it,
  # and that reflexive symlink fails the `noBrokenSymlinks` check.
  #
  # Validate a later version:
  #   ls -ld "$(dirname "$(readlink -f "$(command -v code)")")"/../lib/vscode/resources/app/node_modules.asar.unpacked
  # Symlink means this override still carries the app.
  # Directory means upstream ships it again, so drop the override and rebuild.
  # Then open any file for colors,
  # and confirm `rg _loadVSCodeOnigurumaWASM ~/.config/Code/logs/*/window1/renderer.log` stays empty for the new session.
  programs.vscode.package = pkgs.vscode.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      appdir="$out/lib/vscode/resources/app"
      [ -e "$appdir/node_modules.asar.unpacked" ] || ln -s node_modules "$appdir/node_modules.asar.unpacked"
    '';
  });

  xdg.desktopEntries."code" = {
    name = "Visual Studio Code";
    genericName = "Text Editor";
    exec = "code --password-store=\"gnome-libsecret\"";
    terminal = false;
    icon = "vscode";
    categories = [
      "Development"
      "IDE"
    ];
    type = "Application";
  };
}

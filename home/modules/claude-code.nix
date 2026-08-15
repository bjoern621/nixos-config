{ pkgs, customLib, ... }:

{
  # claude-code ships as native binary, so installing it puts no node on PATH.
  # Plugin hooks exec `node` (caveman UserPromptSubmit tracker) and die without it.
  # Wrapper reaches claude and every process it spawns, global nodejs not needed.
  home.packages = [
    (customLib.wrapWithPrivateDeps pkgs.claude-code {
      bin = "claude";
      binDeps = [ pkgs.nodejs ];
    })
  ];
}

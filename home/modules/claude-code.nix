{
  lib,
  pkgs,
  customLib,
  ...
}:

let
  # Output: "bjoern@nixos:~/.claude Opus 5.5 ctx 7%".
  statusline = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      input=$(cat)
      cwd=$(jq -r '.workspace.current_dir // .cwd // empty' <<<"$input")
      model=$(jq -r '.model.display_name // empty' <<<"$input")
      pct=$(jq -r '.context_window.used_percentage // empty | floor' <<<"$input")

      [ -n "$cwd" ] || cwd=$PWD
      case "$cwd" in
        "$HOME") cwd='~' ;;
        "$HOME"/*) cwd=\~/"''${cwd#"$HOME"/}" ;;
      esac

      green=$'\033[32m'
      yellow=$'\033[33m'
      red=$'\033[31m'
      blue=$'\033[34m'
      # Truecolor: kitty's Monokai Pro palette maps both blue slots to orange.
      lightBlue=$'\033[38;2;124;183;255m'
      reset=$'\033[0m'

      line="''${green}$(whoami)@$(hostname -s)''${reset}:''${blue}''${cwd}''${reset}"
      [ -n "$model" ] && line+=" ''${lightBlue}$model''${reset}"

      if [ -n "$pct" ]; then
        if [ "$pct" -ge 80 ]; then
          color=$red
        elif [ "$pct" -ge 50 ]; then
          color=$yellow
        else
          color=$green
        fi
        line+=" ''${color}ctx ''${pct}%''${reset}"
      fi

      printf '%s' "$line"
    '';
  };

  # Claude Code writes settings.json itself, so a store symlink would fail with EROFS.
  # Seed instead: patch statusLine, leave the rest to the app.
  seedSettings = pkgs.writeShellScript "claude-seed-settings" ''
    set -euo pipefail
    settings="$1"
    mkdir -p "$(dirname "$settings")"
    [ -e "$settings" ] || echo '{}' > "$settings"
    tmp="$(mktemp)"
    ${lib.getExe pkgs.jq} --arg cmd ${lib.getExe statusline} \
      '.statusLine = { type: "command", command: $cmd }' "$settings" > "$tmp"
    mv "$tmp" "$settings"
  '';
in
{
  # claude-code ships as native binary, so installing it puts no node on PATH.
  # Plugin hooks exec `node` (caveman UserPromptSubmit tracker) and die without it.
  # Wrapper reaches claude and every process it spawns, global nodejs not needed.
  home.packages = [
    (customLib.wrapWithPrivateDeps pkgs.claude-code {
      bin = "claude";
      binDeps = [ pkgs.nodejs ];
    })

    # MCP server for Grafana. Claude spawns it by bare command name, so it sits on PATH.
    pkgs.mcp-grafana
  ];

  home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${seedSettings} $HOME/.claude/settings.json
  '';
}

## Makes workspace 2 exclusive to VSCode.
#
# Two-layer approach:
# 1. Window rules float any non-VSCode window on workspace 2 at creation time,
#    preventing tiling layout disruption before any IPC event fires.
# 2. An IPC listener moves those floated windows to the first empty workspace
#    and re-tiles them.
{ pkgs, ... }:

let
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  jq = "${pkgs.jq}/bin/jq";
  socat = "${pkgs.socat}/bin/socat";

  exclusiveWorkspaceScript = pkgs.writeShellScript "exclusive-workspace" ''
    # Find the first workspace (1-10) with no open windows, skipping workspace 2
    find_empty_workspace() {
      local used_workspaces
      used_workspaces=$(${hyprctl} clients -j | ${jq} -r '.[].workspace.id' | sort -un)

      for i in 4 5 6 7 8 9 10; do
        if ! echo "$used_workspaces" | grep -qx "$i"; then
          echo "$i"
          return
        fi
      done
      echo "10"
    }

    handle() {
      local event="$1"
      # openwindow event format: openwindow>>ADDRESS,WORKSPACE,CLASS,TITLE
      if [[ "$event" == openwindow\>\>* ]]; then
        local data="''${event#openwindow>>}"
        local address="''${data%%,*}"
        data="''${data#*,}"
        local workspace="''${data%%,*}"
        data="''${data#*,}"
        local class="''${data%%,*}"

        if [[ "$workspace" == "2" && "$class" != "code" && "$class" != code-* ]]; then
          local target
          target=$(find_empty_workspace)
          local addr="address:0x$address"

          # Move to target workspace and re-tile (window is already floating from the window rule)
          ${hyprctl} --batch \
            "dispatch movetoworkspacesilent $target,$addr ; dispatch settiled $addr"
          ${hyprctl} notify 1 3000 0 "$class nach Workspace $target verschoben"
        fi
      fi
    }

    ${socat} -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while IFS= read -r line; do
      handle "$line"
    done
  '';
in
{
  wayland.windowManager.hyprland.settings = {
    # Float non-VSCode windows on workspace 2 at creation time (static rule,
    # applied before the window is tiled) so they never disrupt the layout.
    windowrule = [
      "float on, match:workspace 2, match:class negative:^code"
    ];

    # exec-once = [
    #   "${exclusiveWorkspaceScript}"
    # ];
  };
}

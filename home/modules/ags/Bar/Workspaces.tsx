import Gtk from "gi://Gtk?version=4.0";
import AstalHyprland from "gi://AstalHyprland";
import { createBinding, For } from "ags";

export default function Workspaces() {
    const hyprland = AstalHyprland.get_default();

    const workspaces = createBinding(
        hyprland,
        "workspaces"
    )((ws) => ws.sort((a, b) => a.id - b.id));

    const focusedWorkspace = createBinding(hyprland, "focusedWorkspace");

    return (
        <Gtk.Box cssClasses={["workspaces"]} spacing={8}>
            <For each={workspaces}>
                {(ws: AstalHyprland.Workspace) => (
                    <Gtk.Button
                        cssClasses={focusedWorkspace((focused) =>
                            focused?.id === ws.id
                                ? ["workspace", "focused"]
                                : ["workspace"]
                        )}
                        onClicked={() => ws.focus()}
                    >
                        <Gtk.Label label={String(ws.id)} />
                    </Gtk.Button>
                )}
            </For>
        </Gtk.Box>
    );
}

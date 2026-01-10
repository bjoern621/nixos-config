import Gtk from "gi://Gtk?version=4.0";
import AstalTray from "gi://AstalTray";
import { For, createBinding } from "ags";

export default function Tray() {
    const tray = AstalTray.get_default();
    const items = createBinding(tray, "items");

    const init = (btn: Gtk.MenuButton, item: AstalTray.TrayItem) => {
        btn.menuModel = item.menuModel;
        btn.insert_action_group("dbusmenu", item.actionGroup);
        item.connect("notify::action-group", () => {
            btn.insert_action_group("dbusmenu", item.actionGroup);
        });
    };

    return (
        <Gtk.Box>
            <For each={items}>
                {(item) => (
                    <Gtk.MenuButton $={(self) => init(self, item)}>
                        <Gtk.Image gicon={createBinding(item, "gicon")} />
                    </Gtk.MenuButton>
                )}
            </For>
        </Gtk.Box>
    );
}

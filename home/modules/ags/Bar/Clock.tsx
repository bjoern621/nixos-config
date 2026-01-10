import GLib from "gi://GLib";
import Gtk from "gi://Gtk?version=4.0";
import { createPoll } from "ags/time";

export default function Clock() {
    const time = createPoll("", 1000, () => {
        return GLib.DateTime.new_now_local().format(
            " %a, %e %b \u00B7 %H:%M"
        )!;
    });

    return (
        <Gtk.MenuButton cssClasses={["clock-button"]}>
            <Gtk.Label label={time} />
            <Gtk.Popover>
                <Gtk.Calendar />
            </Gtk.Popover>
        </Gtk.MenuButton>
    );
}

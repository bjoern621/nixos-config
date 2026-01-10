import app from "ags/gtk4/app";
import Astal from "gi://Astal?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Gtk from "gi://Gtk?version=4.0";
import { onCleanup } from "ags";

import Tray from "./Tray";
import Wireless from "./Wireless";
import Clock from "./Clock";
import Battery from "./Battery";
import Workspaces from "./Workspaces";

export default function Bar({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
    let win: Astal.Window;
    const { TOP, LEFT, RIGHT } = Astal.WindowAnchor;

    onCleanup(() => {
        win.destroy();
    });

    return (
        <Astal.Window
            $={(self) => (win = self)}
            visible
            namespace="bar"
            name={`bar-${gdkmonitor.connector}`}
            gdkmonitor={gdkmonitor}
            exclusivity={Astal.Exclusivity.EXCLUSIVE}
            anchor={TOP | LEFT | RIGHT}
            application={app}
            cssClasses={["bar"]}
            overflow={Gtk.Overflow.VISIBLE}
        >
            <Gtk.CenterBox>
                <Gtk.Box $type="start" cssClasses={["bordered"]}>
                    <Workspaces />
                </Gtk.Box>

                <Gtk.Box $type="center" cssClasses={["bordered"]}>
                    <Clock />
                </Gtk.Box>

                <Gtk.Box $type="end" cssClasses={["bordered"]} spacing={8}>
                    <Tray />
                    <Wireless />
                    <Battery />
                </Gtk.Box>
            </Gtk.CenterBox>
        </Astal.Window>
    );
}

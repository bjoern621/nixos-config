import app from "ags/gtk4/app";
import Astal from "gi://Astal?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Gtk from "gi://Gtk?version=4.0";
import { onCleanup } from "ags";

import Mpris from "./Mpris";
import Tray from "./Tray";
import Wireless from "./Wireless";
import AudioOutput from "./AudioOutput";
import Battery from "./Battery";
import Clock from "./Clock";

export default function Bar({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
    let win: Astal.Window;
    const { TOP, LEFT, RIGHT } = Astal.WindowAnchor;

    onCleanup(() => {
        // Root components (windows) are not automatically destroyed.
        // When the monitor is disconnected from the system, this callback
        // is run from the parent <For> which allows us to destroy the window
        win.destroy();
    });

    return (
        <Astal.Window
            $={(self) => (win = self)}
            visible
            namespace="my-bar"
            name={`bar-${gdkmonitor.connector}`}
            gdkmonitor={gdkmonitor}
            exclusivity={Astal.Exclusivity.EXCLUSIVE}
            anchor={TOP | LEFT | RIGHT}
            application={app}
        >
            <Gtk.CenterBox>
                <Gtk.Box $type="start">
                    <Clock />
                    <Mpris />
                </Gtk.Box>
                <Gtk.Box $type="end">
                    <Tray />
                    <Wireless />
                    <AudioOutput />
                    <Battery />
                </Gtk.Box>
            </Gtk.CenterBox>
        </Astal.Window>
    );
}

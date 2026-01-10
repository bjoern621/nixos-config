import Gtk from "gi://Gtk?version=4.0";
import AstalWp from "gi://AstalWp";
import { createBinding } from "ags";

export default function AudioOutput() {
    const { defaultSpeaker: speaker } = AstalWp.get_default()!;

    return (
        <Gtk.MenuButton>
            <Gtk.Image iconName={createBinding(speaker, "volumeIcon")} />
            <Gtk.Popover>
                <Gtk.Box>
                    <Gtk.Scale
                        widthRequest={260}
                        onChangeValue={(scale) =>
                            speaker.set_volume(scale.get_value())
                        }
                        adjustment={
                            new Gtk.Adjustment({
                                lower: 0,
                                upper: 1,
                                value: speaker.volume,
                            })
                        }
                    />
                </Gtk.Box>
            </Gtk.Popover>
        </Gtk.MenuButton>
    );
}

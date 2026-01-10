import Gtk from "gi://Gtk?version=4.0";
import AstalBattery from "gi://AstalBattery";
import AstalPowerProfiles from "gi://AstalPowerProfiles";
import { createBinding } from "ags";

export default function Battery() {
    const battery = AstalBattery.get_default();
    const powerprofiles = AstalPowerProfiles.get_default();

    const percentage = createBinding(
        battery,
        "percentage"
    )((p) => `${Math.floor(p * 100)} %`);

    const setProfile = (profile: string) => {
        powerprofiles.set_active_profile(profile);
    };

    return (
        <Gtk.MenuButton>
            <Gtk.Box>
                <Gtk.Image iconName={createBinding(battery, "iconName")} />
                <Gtk.Label label={percentage} />
            </Gtk.Box>
            <Gtk.Popover>
                <Gtk.Box orientation={Gtk.Orientation.VERTICAL}>
                    {powerprofiles.get_profiles().map(({ profile }) => (
                        <Gtk.Button onClicked={() => setProfile(profile)}>
                            <Gtk.Label label={profile} xalign={0} />
                        </Gtk.Button>
                    ))}
                </Gtk.Box>
            </Gtk.Popover>
        </Gtk.MenuButton>
    );
}

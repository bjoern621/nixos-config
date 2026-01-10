import Gtk from "gi://Gtk?version=4.0";
import AstalNetwork from "gi://AstalNetwork";
import { For, With, createBinding } from "ags";
import { execAsync } from "ags/process";

export default function Wireless() {
    const network = AstalNetwork.get_default();
    const wifi = createBinding(network, "wifi");

    const sorted = (arr: Array<AstalNetwork.AccessPoint>) => {
        return arr
            .filter((ap) => !!ap.ssid)
            .sort((a, b) => b.strength - a.strength);
    };

    async function connect(ap: AstalNetwork.AccessPoint) {
        try {
            await execAsync(`nmcli d wifi connect ${ap.bssid}`);
        } catch (error) {
            console.error(error);
        }
    }

    return (
        <Gtk.Box visible={wifi(Boolean)}>
            <With value={wifi}>
                {(wifi) =>
                    wifi && (
                        <Gtk.MenuButton>
                            <Gtk.Image
                                iconName={createBinding(wifi, "iconName")}
                            />
                            <Gtk.Popover>
                                <Gtk.Box
                                    orientation={Gtk.Orientation.VERTICAL}
                                    cssClasses={["wireless-menu"]}
                                >
                                    <For
                                        each={createBinding(
                                            wifi,
                                            "accessPoints"
                                        )(sorted)}
                                    >
                                        {(ap: AstalNetwork.AccessPoint) => (
                                            <Gtk.Button
                                                onClicked={() => connect(ap)}
                                            >
                                                <Gtk.Box spacing={4}>
                                                    <Gtk.Image
                                                        iconName={createBinding(
                                                            ap,
                                                            "iconName"
                                                        )}
                                                    />
                                                    <Gtk.Label
                                                        label={createBinding(
                                                            ap,
                                                            "ssid"
                                                        )}
                                                    />
                                                    <Gtk.Image
                                                        iconName="object-select-symbolic"
                                                        visible={createBinding(
                                                            wifi,
                                                            "activeAccessPoint"
                                                        )(
                                                            (active) =>
                                                                active === ap
                                                        )}
                                                    />
                                                </Gtk.Box>
                                            </Gtk.Button>
                                        )}
                                    </For>
                                </Gtk.Box>
                            </Gtk.Popover>
                        </Gtk.MenuButton>
                    )
                }
            </With>
        </Gtk.Box>
    );
}

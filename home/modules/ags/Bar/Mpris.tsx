import Gtk from "gi://Gtk?version=4.0";
import AstalMpris from "gi://AstalMpris";
import AstalApps from "gi://AstalApps";
import { For, createBinding } from "ags";

export default function Mpris() {
    const mpris = AstalMpris.get_default();
    const apps = new AstalApps.Apps();
    const players = createBinding(mpris, "players");

    return (
        <Gtk.MenuButton>
            <Gtk.Box>
                <For each={players}>
                    {(player) => {
                        const [app] = apps.exact_query(player.entry);
                        return (
                            <Gtk.Image
                                visible={!!app.iconName}
                                iconName={app?.iconName}
                            />
                        );
                    }}
                </For>
            </Gtk.Box>
            <Gtk.Popover>
                <Gtk.Box spacing={4} orientation={Gtk.Orientation.VERTICAL}>
                    <For each={players}>
                        {(player) => (
                            <Gtk.Box spacing={4} widthRequest={200}>
                                <Gtk.Box
                                    overflow={Gtk.Overflow.HIDDEN}
                                    css="border-radius: 8px;"
                                >
                                    <Gtk.Image
                                        pixelSize={64}
                                        file={createBinding(player, "coverArt")}
                                    />
                                </Gtk.Box>
                                <Gtk.Box
                                    valign={Gtk.Align.CENTER}
                                    orientation={Gtk.Orientation.VERTICAL}
                                >
                                    <Gtk.Label
                                        xalign={0}
                                        label={createBinding(player, "title")}
                                    />
                                    <Gtk.Label
                                        xalign={0}
                                        label={createBinding(player, "artist")}
                                    />
                                </Gtk.Box>
                                <Gtk.Box hexpand halign={Gtk.Align.END}>
                                    <Gtk.Button
                                        onClicked={() => player.previous()}
                                        visible={createBinding(
                                            player,
                                            "canGoPrevious"
                                        )}
                                    >
                                        <Gtk.Image iconName="media-seek-backward-symbolic" />
                                    </Gtk.Button>
                                    <Gtk.Button
                                        onClicked={() => player.play_pause()}
                                        visible={createBinding(
                                            player,
                                            "canControl"
                                        )}
                                    >
                                        <Gtk.Box>
                                            <Gtk.Image
                                                iconName="media-playback-start-symbolic"
                                                visible={createBinding(
                                                    player,
                                                    "playbackStatus"
                                                )(
                                                    (s) =>
                                                        s ===
                                                        AstalMpris
                                                            .PlaybackStatus
                                                            .PLAYING
                                                )}
                                            />
                                            <Gtk.Image
                                                iconName="media-playback-pause-symbolic"
                                                visible={createBinding(
                                                    player,
                                                    "playbackStatus"
                                                )(
                                                    (s) =>
                                                        s !==
                                                        AstalMpris
                                                            .PlaybackStatus
                                                            .PLAYING
                                                )}
                                            />
                                        </Gtk.Box>
                                    </Gtk.Button>
                                    <Gtk.Button
                                        onClicked={() => player.next()}
                                        visible={createBinding(
                                            player,
                                            "canGoNext"
                                        )}
                                    >
                                        <Gtk.Image iconName="media-seek-forward-symbolic" />
                                    </Gtk.Button>
                                </Gtk.Box>
                            </Gtk.Box>
                        )}
                    </For>
                </Gtk.Box>
            </Gtk.Popover>
        </Gtk.MenuButton>
    );
}
